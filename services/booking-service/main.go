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
	"github.com/omnibus-ea/booking-service/internal/config"
	"github.com/omnibus-ea/booking-service/internal/handlers"
	"github.com/omnibus-ea/booking-service/internal/locker"
	"github.com/omnibus-ea/booking-service/internal/middleware"
	pb "github.com/omnibus-ea/booking-service/proto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

func main() {
	cfg := config.Load()
	logrus.SetFormatter(&logrus.JSONFormatter{})

	db := config.InitPostgres(cfg)
	redisClient := config.InitRedis(cfg)
	redlock := locker.NewRedlock(redisClient, cfg)

	bookingHandler := handlers.NewBookingHandler(db, redisClient, redlock, cfg)

	go func() {
		lis, err := net.Listen("tcp", fmt.Sprintf(":%s", cfg.GRPCPort))
		if err != nil {
			log.Fatalf("failed to listen: %v", err)
		}
		s := grpc.NewServer()
		pb.RegisterBookingServiceServer(s, bookingHandler)
		logrus.Infof("gRPC server on port %s", cfg.GRPCPort)
		if err := s.Serve(lis); err != nil {
			log.Fatalf("failed to serve: %v", err)
		}
	}()

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORS())
	r.Use(middleware.RequestLogger())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy", "service": "booking-service"})
	})
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	api := r.Group("/api/v1/bookings")
	{
		api.POST("/lock", bookingHandler.LockSeat)
		api.POST("/confirm", bookingHandler.ConfirmBooking)
		api.GET("/status/:pnr", bookingHandler.GetBookingStatus)
		api.POST("/cancel", bookingHandler.CancelBooking)
	}

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.HTTPPort),
		Handler:      r,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logrus.Fatalf("HTTP error: %v", err)
		}
	}()

	logrus.Infof("Booking Service started on HTTP:%s gRPC:%s", cfg.HTTPPort, cfg.GRPCPort)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	logrus.Info("Booking Service shutdown")
}
