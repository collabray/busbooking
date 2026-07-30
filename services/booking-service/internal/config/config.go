package config

import (
	"context"
	"database/sql"
	"fmt"
	"log"

	"github.com/lib/pq"
	"github.com/redis/go-redis/v9"
	"github.com/spf13/viper"
)

type Config struct {
	HTTPPort      string `mapstructure:"HTTP_PORT"`
	GRPCPort      string `mapstructure:"GRPC_PORT"`
	DBHost        string `mapstructure:"DB_HOST"`
	DBPort        string `mapstructure:"DB_PORT"`
	DBUser        string `mapstructure:"DB_USER"`
	DBPassword    string `mapstructure:"DB_PASSWORD"`
	DBName        string `mapstructure:"DB_NAME"`
	RedisHost     string `mapstructure:"REDIS_HOST"`
	RedisPort     string `mapstructure:"REDIS_PORT"`
	RedisPassword string `mapstructure:"REDIS_PASSWORD"`
	LockTTL       int    `mapstructure:"LOCK_TTL_SECONDS"`
}

func Load() *Config {
	viper.AutomaticEnv()
	viper.SetDefault("HTTP_PORT", "8080")
	viper.SetDefault("GRPC_PORT", "9090")
	viper.SetDefault("LOCK_TTL_SECONDS", 300)

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
		log.Fatalf("DB connection failed: %v", err)
	}
	db.SetMaxOpenConns(200)
	db.SetMaxIdleConns(50)
	return db
}

func InitRedis(cfg *Config) *redis.Client {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.RedisHost, cfg.RedisPort),
		Password: cfg.RedisPassword,
		DB:       0,
		PoolSize: 200,
	})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		log.Fatalf("Redis connection failed: %v", err)
	}
	return rdb
}
