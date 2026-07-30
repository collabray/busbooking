package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/omnibus-ea/auth-service/internal/config"
	"github.com/omnibus-ea/auth-service/internal/handlers"
	"github.com/omnibus-ea/auth-service/internal/middleware"
	pb "github.com/omnibus-ea/auth-service/proto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

func main() {
	cfg := config.Load()
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.SetLevel(logrus.InfoLevel)

	db := config.InitPostgres(cfg)
	redisClient := config.InitRedis(cfg)
	kmsClient := config.InitKMS(cfg)

	authHandler := handlers.NewAuthHandler(db, redisClient, kmsClient, cfg)
	webauthnHandler := handlers.NewWebAuthnHandler(db, cfg)

	go func() {
		lis, err := net.Listen("tcp", fmt.Sprintf(":%s", cfg.GRPCPort))
		if err != nil {
			log.Fatalf("failed to listen: %v", err)
		}
		s := grpc.NewServer(
			grpc.UnaryInterceptor(middleware.GRPCAuthInterceptor(cfg)),
		)
		pb.RegisterAuthServiceServer(s, authHandler)
		logrus.Infof("gRPC server starting on port %s", cfg.GRPCPort)
		if err := s.Serve(lis); err != nil {
			log.Fatalf("failed to serve: %v", err)
		}
	}()

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORS())
	r.Use(middleware.RateLimit(redisClient, cfg))
	r.Use(middleware.RequestLogger())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy", "service": "auth-service", "region": cfg.Region})
	})
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	api := r.Group("/api/v1/auth")
	{
		api.POST("/otp/request", authHandler.RequestOTP)
		api.POST("/otp/verify", authHandler.VerifyOTP)
		api.POST("/token/refresh", authHandler.RefreshToken)
		api.POST("/logout", middleware.AuthMiddleware(cfg), authHandler.Logout)
		api.GET("/me", middleware.AuthMiddleware(cfg), authHandler.GetProfile)
		api.POST("/kyc/submit", middleware.AuthMiddleware(cfg), authHandler.SubmitKYC)
		api.GET("/kyc/status", middleware.AuthMiddleware(cfg), authHandler.GetKYCStatus)
	}

	admin := r.Group("/api/v1/admin/auth")
	{
		admin.POST("/webauthn/register/begin", webauthnHandler.BeginRegistration)
		admin.POST("/webauthn/register/finish", webauthnHandler.FinishRegistration)
		admin.POST("/webauthn/login/begin", webauthnHandler.BeginLogin)
		admin.POST("/webauthn/login/finish", webauthnHandler.FinishLogin)
	}

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.HTTPPort),
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logrus.Fatalf("HTTP server error: %v", err)
		}
	}()

	logrus.Infof("Auth Service started - HTTP:%s gRPC:%s", cfg.HTTPPort, cfg.GRPCPort)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		logrus.Errorf("Server forced to shutdown: %v", err)
	}
	logrus.Info("Auth Service shutdown complete")
}
