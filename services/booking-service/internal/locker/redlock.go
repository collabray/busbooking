package locker

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/omnibus-ea/booking-service/internal/config"
	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
)

type Redlock struct {
	redis  *redis.Client
	ttl    time.Duration
	script *redis.Script
}

func NewRedlock(redis *redis.Client, cfg *config.Config) *Redlock {
	luaScript := redis.NewScript(`
		local key = KEYS[1]
		local lock_id = ARGV[1]
		local ttl = ARGV[2]
		if redis.call("EXISTS", key) == 0 then
			redis.call("SET", key, lock_id, "PX", ttl)
			return 1
		else
			return 0
		end
	`)
	return &Redlock{
		redis:  redis,
		ttl:    time.Duration(cfg.LockTTL) * time.Second,
		script: luaScript,
	}
}

func (r *Redlock) GenerateLockID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func (r *Redlock) AcquireLock(ctx context.Context, busID, seatID string) (string, bool, error) {
	lockID := r.GenerateLockID()
	key := fmt.Sprintf("lock:bus:%s:seat:%s", busID, seatID)

	result, err := r.script.Run(ctx, r.redis, []string{key}, lockID, r.ttl.Milliseconds()).Int()
	if err != nil {
		logrus.WithError(err).Error("Redlock acquisition failed")
		return "", false, err
	}

	if result == 1 {
		logrus.Infof("Lock acquired: %s -> %s", key, lockID)
		return lockID, true, nil
	}
	return "", false, nil
}

func (r *Redlock) ReleaseLock(ctx context.Context, busID, seatID, lockID string) error {
	key := fmt.Sprintf("lock:bus:%s:seat:%s", busID, seatID)

	releaseScript := redis.NewScript(`
		local key = KEYS[1]
		local lock_id = ARGV[1]
		if redis.call("GET", key) == lock_id then
			return redis.call("DEL", key)
		else
			return 0
		end
	`)

	_, err := releaseScript.Run(ctx, r.redis, []string{key}, lockID).Result()
	if err != nil {
		logrus.WithError(err).Warn("Lock release failed")
		return err
	}
	logrus.Infof("Lock released: %s", key)
	return nil
}

func (r *Redlock) ExtendLock(ctx context.Context, busID, seatID, lockID string) error {
	key := fmt.Sprintf("lock:bus:%s:seat:%s", busID, seatID)
	extendScript := redis.NewScript(`
		local key = KEYS[1]
		local lock_id = ARGV[1]
		local ttl = ARGV[2]
		if redis.call("GET", key) == lock_id then
			return redis.call("PEXPIRE", key, ttl)
		else
			return 0
		end
	`)
	_, err := extendScript.Run(ctx, r.redis, []string{key}, lockID, r.ttl.Milliseconds()).Result()
	return err
}
