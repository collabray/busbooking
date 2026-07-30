package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	_ "github.com/lib/pq"
)

type LedgerEntry struct {
	EntryID       string          `json:"entry_id" db:"entry_id"`
	WalletID      string          `json:"wallet_id" db:"wallet_id"`
	TransactionID string          `json:"transaction_id" db:"transaction_id"`
	EntryType     string          `json:"entry_type" db:"entry_type"` // DEBIT or CREDIT
	Amount        float64         `json:"amount" db:"amount"`
	Currency      string          `json:"currency" db:"currency"`
	BalanceAfter  float64         `json:"balance_after" db:"balance_after"`
	Description   string          `json:"description" db:"description"`
	CreatedAt     time.Time       `json:"created_at" db:"created_at"`
}

type Wallet struct {
	WalletID    string    `json:"wallet_id" db:"wallet_id"`
	EntityID    string    `json:"entity_id" db:"entity_id"` // operator_id or user_id
	EntityType  string    `json:"entity_type" db:"entity_type"` // OPERATOR or PLATFORM
	Balance     float64   `json:"balance" db:"balance"`
	Currency    string    `json:"currency" db:"currency"`
	Status      string    `json:"status" db:"status"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

func main() {
	logrus.SetFormatter(&logrus.JSONFormatter{})

	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	dbUser := os.Getenv("DB_USER")
	dbPass := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		dbHost, dbPort, dbUser, dbPass, dbName)
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		logrus.Fatal(err)
	}
	defer db.Close()
	db.SetMaxOpenConns(100)

	r := gin.New()
	r.Use(gin.Recovery())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy", "service": "wallet-service"})
	})
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	api := r.Group("/api/v1/wallets")
	{
		api.POST("/create", func(c *gin.Context) {
			var req struct {
				EntityID   string `json:"entity_id" binding:"required"`
				EntityType string `json:"entity_type" binding:"required,oneof=OPERATOR PLATFORM"`
				Currency   string `json:"currency" binding:"required,len=3"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			walletID := fmt.Sprintf("WAL_%s_%d", req.EntityID, time.Now().Unix())
			_, err := db.Exec(`INSERT INTO wallets (wallet_id, entity_id, entity_type, balance, currency, status, created_at, updated_at)
				VALUES ($1, $2, $3, 0, $4, 'ACTIVE', NOW(), NOW())`,
				walletID, req.EntityID, req.EntityType, req.Currency)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusCreated, gin.H{"wallet_id": walletID, "balance": 0, "currency": req.Currency})
		})

		api.GET("/:wallet_id/balance", func(c *gin.Context) {
			walletID := c.Param("wallet_id")
			var wallet Wallet
			err := db.QueryRow(`SELECT wallet_id, entity_id, entity_type, balance, currency, status, created_at, updated_at
				FROM wallets WHERE wallet_id = $1`, walletID).Scan(
				&wallet.WalletID, &wallet.EntityID, &wallet.EntityType, &wallet.Balance,
				&wallet.Currency, &wallet.Status, &wallet.CreatedAt, &wallet.UpdatedAt)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "wallet not found"})
				return
			}
			c.JSON(http.StatusOK, wallet)
		})

		api.POST("/:wallet_id/credit", func(c *gin.Context) {
			walletID := c.Param("wallet_id")
			var req struct {
				Amount        float64 `json:"amount" binding:"required,gt=0"`
				TransactionID string  `json:"transaction_id" binding:"required"`
				Description   string  `json:"description" binding:"required"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			tx, err := db.Begin()
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "transaction start failed"})
				return
			}
			defer tx.Rollback()

			var currentBalance float64
			var currency string
			err = tx.QueryRow(`SELECT balance, currency FROM wallets WHERE wallet_id = $1 FOR UPDATE`, walletID).Scan(&currentBalance, &currency)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "wallet not found"})
				return
			}

			newBalance := currentBalance + req.Amount
			entryID := fmt.Sprintf("ENT_%d", time.Now().UnixNano())

			_, err = tx.Exec(`UPDATE wallets SET balance = $1, updated_at = NOW() WHERE wallet_id = $2`, newBalance, walletID)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "balance update failed"})
				return
			}

			_, err = tx.Exec(`INSERT INTO ledger_entries (entry_id, wallet_id, transaction_id, entry_type, amount, currency, balance_after, description, created_at)
				VALUES ($1, $2, $3, 'CREDIT', $4, $5, $6, $7, NOW())`,
				entryID, walletID, req.TransactionID, req.Amount, currency, newBalance, req.Description)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "ledger entry failed"})
				return
			}

			if err := tx.Commit(); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "commit failed"})
				return
			}

			c.JSON(http.StatusOK, gin.H{"wallet_id": walletID, "new_balance": newBalance, "entry_id": entryID})
		})

		api.POST("/:wallet_id/debit", func(c *gin.Context) {
			walletID := c.Param("wallet_id")
			var req struct {
				Amount        float64 `json:"amount" binding:"required,gt=0"`
				TransactionID string  `json:"transaction_id" binding:"required"`
				Description   string  `json:"description" binding:"required"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			tx, err := db.Begin()
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "transaction start failed"})
				return
			}
			defer tx.Rollback()

			var currentBalance float64
			var currency string
			err = tx.QueryRow(`SELECT balance, currency FROM wallets WHERE wallet_id = $1 FOR UPDATE`, walletID).Scan(&currentBalance, &currency)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "wallet not found"})
				return
			}

			if currentBalance < req.Amount {
				c.JSON(http.StatusBadRequest, gin.H{"error": "insufficient balance"})
				return
			}

			newBalance := currentBalance - req.Amount
			entryID := fmt.Sprintf("ENT_%d", time.Now().UnixNano())

			_, err = tx.Exec(`UPDATE wallets SET balance = $1, updated_at = NOW() WHERE wallet_id = $2`, newBalance, walletID)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "balance update failed"})
				return
			}

			_, err = tx.Exec(`INSERT INTO ledger_entries (entry_id, wallet_id, transaction_id, entry_type, amount, currency, balance_after, description, created_at)
				VALUES ($1, $2, $3, 'DEBIT', $4, $5, $6, $7, NOW())`,
				entryID, walletID, req.TransactionID, req.Amount, currency, newBalance, req.Description)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "ledger entry failed"})
				return
			}

			if err := tx.Commit(); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "commit failed"})
				return
			}

			c.JSON(http.StatusOK, gin.H{"wallet_id": walletID, "new_balance": newBalance, "entry_id": entryID})
		})

		api.GET("/:wallet_id/ledger", func(c *gin.Context) {
			walletID := c.Param("wallet_id")
			rows, err := db.Query(`SELECT entry_id, wallet_id, transaction_id, entry_type, amount, currency, balance_after, description, created_at
				FROM ledger_entries WHERE wallet_id = $1 ORDER BY created_at DESC LIMIT 100`, walletID)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			defer rows.Close()

			var entries []LedgerEntry
			for rows.Next() {
				var e LedgerEntry
				rows.Scan(&e.EntryID, &e.WalletID, &e.TransactionID, &e.EntryType, &e.Amount, &e.Currency, &e.BalanceAfter, &e.Description, &e.CreatedAt)
				entries = append(entries, e)
			}
			c.JSON(http.StatusOK, gin.H{"wallet_id": walletID, "entries": entries})
		})

		api.POST("/payout", func(c *gin.Context) {
			var req struct {
				WalletID      string  `json:"wallet_id" binding:"required"`
				Amount        float64 `json:"amount" binding:"required,gt=0"`
				Destination   string  `json:"destination" binding:"required"` // phone or bank account
				Method        string  `json:"method" binding:"required,oneof=MOBILE_MONEY RTGS"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			// Trigger payout via payment provider
			c.JSON(http.StatusAccepted, gin.H{
				"payout_id": fmt.Sprintf("PO_%d", time.Now().UnixNano()),
				"status": "PROCESSING",
				"wallet_id": req.WalletID,
				"amount": req.Amount,
				"method": req.Method,
			})
		})
	}

	logrus.Info("Wallet Service starting on :8080")
	r.Run(":8080")
}
