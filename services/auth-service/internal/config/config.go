package config

import (
	"context"
	"database/sql"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/lib/pq"
	"github.com/redis/go-redis/v9"
	"github.com/spf13/viper"
)

type Config struct {
	HTTPPort        string `mapstructure:"HTTP_PORT"`
	GRPCPort        string `mapstructure:"GRPC_PORT"`
	DBHost          string `mapstructure:"DB_HOST"`
	DBPort          string `mapstructure:"DB_PORT"`
	DBUser          string `mapstructure:"DB_USER"`
	DBPassword      string `mapstructure:"DB_PASSWORD"`
	DBName          string `mapstructure:"DB_NAME"`
	RedisHost       string `mapstructure:"REDIS_HOST"`
	RedisPort       string `mapstructure:"REDIS_PORT"`
	RedisPassword   string `mapstructure:"REDIS_PASSWORD"`
	JWTSecret       string `mapstructure:"JWT_SECRET"`
	JWTAccessTTL    int    `mapstructure:"JWT_ACCESS_TTL_MINUTES"`
	JWTRefreshTTL   int    `mapstructure:"JWT_REFRESH_TTL_DAYS"`
	FirebaseAPIKey  string `mapstructure:"FIREBASE_API_KEY"`
	KMSKeyID        string `mapstructure:"KMS_KEY_ID"`
	Region          string `mapstructure:"AWS_REGION"`
	WebAuthnRPID    string `mapstructure:"WEBAUTHN_RP_ID"`
	WebAuthnOrigin  string `mapstructure:"WEBAUTHN_ORIGIN"`
}

func Load() *Config {
	viper.AutomaticEnv()
	viper.SetDefault("HTTP_PORT", "8080")
	viper.SetDefault("GRPC_PORT", "9090")
	viper.SetDefault("JWT_ACCESS_TTL_MINUTES", 5)
	viper.SetDefault("JWT_REFRESH_TTL_DAYS", 30)
	viper.SetDefault("AWS_REGION", "af-south-1")

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}
	return &cfg
}

func InitPostgres(cfg *Config) *sql.DB {
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName)
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	db.SetMaxOpenConns(100)
	db.SetMaxIdleConns(20)
	db.SetConnMaxLifetime(0)
	return db
}

func InitRedis(cfg *Config) *redis.Client {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.RedisHost, cfg.RedisPort),
		Password: cfg.RedisPassword,
		DB:       0,
		PoolSize: 100,
	})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	return rdb
}

func InitKMS(cfg *Config) *kms.Client {
	awsCfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(cfg.Region))
	if err != nil {
		log.Fatalf("Failed to load AWS config: %v", err)
	}
	return kms.NewFromConfig(awsCfg)
}
