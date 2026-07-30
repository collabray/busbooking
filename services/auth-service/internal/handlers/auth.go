package handlers

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/omnibus-ea/auth-service/internal/config"
	"github.com/omnibus-ea/auth-service/internal/models"
	pb "github.com/omnibus-ea/auth-service/proto"
	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
)

type AuthHandler struct {
	db         *sql.DB
	redis      *redis.Client
	kmsClient  *kms.Client
	cfg        *config.Config
	pb.UnimplementedAuthServiceServer
}

func NewAuthHandler(db *sql.DB, redis *redis.Client, kmsClient *kms.Client, cfg *config.Config) *AuthHandler {
	return &AuthHandler{db: db, redis: redis, kmsClient: kmsClient, cfg: cfg}
}

func (h *AuthHandler) encryptPII(plaintext string) (string, string, error) {
	dkInput := &kms.GenerateDataKeyInput{
		KeyId:   &h.cfg.KMSKeyID,
		KeySpec: "AES_256",
	}
	dkOut, err := h.kmsClient.GenerateDataKey(context.Background(), dkInput)
	if err != nil {
		return "", "", fmt.Errorf("kms generate data key: %w", err)
	}
	defer clear(dkOut.Plaintext)

	block, err := aes.NewCipher(dkOut.Plaintext)
	if err != nil {
		return "", "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", "", err
	}
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	encryptedKey := base64.StdEncoding.EncodeToString(dkOut.CiphertextBlob)
	encryptedData := base64.StdEncoding.EncodeToString(ciphertext)
	return encryptedData, encryptedKey, nil
}

func (h *AuthHandler) generateTokens(userID uuid.UUID, phone string) (string, string, error) {
	accessClaims := jwt.MapClaims{
		"sub":   userID.String(),
		"phone": phone,
		"type":  "access",
		"iat":   time.Now().Unix(),
		"exp":   time.Now().Add(time.Duration(h.cfg.JWTAccessTTL) * time.Minute).Unix(),
		"jti":   uuid.New().String(),
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessString, err := accessToken.SignedString([]byte(h.cfg.JWTSecret))
	if err != nil {
		return "", "", err
	}

	refreshClaims := jwt.MapClaims{
		"sub":  userID.String(),
		"type": "refresh",
		"iat":  time.Now().Unix(),
		"exp":  time.Now().Add(time.Duration(h.cfg.JWTRefreshTTL) * 24 * time.Hour).Unix(),
		"jti":  uuid.New().String(),
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshString, err := refreshToken.SignedString([]byte(h.cfg.JWTSecret))
	if err != nil {
		return "", "", err
	}

	hash := sha256.Sum256([]byte(refreshString))
	h.redis.Set(context.Background(),
		fmt.Sprintf("refresh:%s", hex.EncodeToString(hash[:])),
		userID.String(),
		time.Duration(h.cfg.JWTRefreshTTL)*24*time.Hour)

	return accessString, refreshString, nil
}

func (h *AuthHandler) RequestOTP(c *gin.Context) {
	var req struct {
		PhoneNumber string `json:"phone_number" binding:"required,e164"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	key := fmt.Sprintf("otp_limit:%s", req.PhoneNumber)
	count, _ := h.redis.Get(context.Background(), key).Int()
	if count >= 3 {
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "OTP request limit exceeded. Try again later."})
		return
	}

	otpCode := fmt.Sprintf("%06d", time.Now().UnixNano()%1000000)
	h.redis.Set(context.Background(), fmt.Sprintf("otp:%s", req.PhoneNumber), otpCode, 5*time.Minute)
	h.redis.Incr(context.Background(), key)
	h.redis.Expire(context.Background(), key, 10*time.Minute)

	logrus.Infof("OTP for %s: %s", req.PhoneNumber, otpCode)
	c.JSON(http.StatusOK, gin.H{"message": "OTP sent successfully", "expires_in": 300})
}

func (h *AuthHandler) VerifyOTP(c *gin.Context) {
	var req struct {
		PhoneNumber string `json:"phone_number" binding:"required,e164"`
		OTP         string `json:"otp" binding:"required,len=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	storedOTP, err := h.redis.Get(context.Background(), fmt.Sprintf("otp:%s", req.PhoneNumber)).Result()
	if err == redis.Nil || storedOTP != req.OTP {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired OTP"})
		return
	}

	h.redis.Del(context.Background(), fmt.Sprintf("otp:%s", req.PhoneNumber))

	var userID uuid.UUID
	var user models.User
	err = h.db.QueryRowContext(c,
		`SELECT user_id, phone_number, legal_name, kyc_status FROM users WHERE phone_number = $1`,
		req.PhoneNumber).Scan(&userID, &user.PhoneNumber, &user.LegalName, &user.KYCStatus)

	if err == sql.ErrNoRows {
		userID = uuid.New()
		phoneEnc, phoneKey, err := h.encryptPII(req.PhoneNumber)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "encryption failed"})
			return
		}
		_, err = h.db.ExecContext(c,
			`INSERT INTO users (user_id, phone_number, phone_encrypted, encryption_key, kyc_status, kyc_tier, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, 'PENDING', 0, NOW(), NOW())`,
			userID, req.PhoneNumber, phoneEnc, phoneKey)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
			return
		}
		user.KYCStatus = "PENDING"
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}

	accessToken, refreshToken, err := h.generateTokens(userID, req.PhoneNumber)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "token generation failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  accessToken,
		"refresh_token": refreshToken,
		"token_type":    "Bearer",
		"expires_in":    h.cfg.JWTAccessTTL * 60,
		"user": gin.H{
			"user_id":    userID,
			"kyc_status": user.KYCStatus,
		},
	})
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	token, err := jwt.Parse(req.RefreshToken, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return []byte(h.cfg.JWTSecret), nil
	})
	if err != nil || !token.Valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid refresh token"})
		return
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || claims["type"] != "refresh" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token type"})
		return
	}

	hash := sha256.Sum256([]byte(req.RefreshToken))
	_, err = h.redis.Get(context.Background(), fmt.Sprintf("refresh:%s", hex.EncodeToString(hash[:]))).Result()
	if err == redis.Nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "token revoked"})
		return
	}

	userID, _ := uuid.Parse(claims["sub"].(string))
	var phone string
	err = h.db.QueryRowContext(c, `SELECT phone_number FROM users WHERE user_id = $1`, userID).Scan(&phone)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not found"})
		return
	}

	h.redis.Del(context.Background(), fmt.Sprintf("refresh:%s", hex.EncodeToString(hash[:])))

	accessToken, newRefreshToken, err := h.generateTokens(userID, phone)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "token generation failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  accessToken,
		"refresh_token": newRefreshToken,
		"token_type":    "Bearer",
		"expires_in":    h.cfg.JWTAccessTTL * 60,
	})
}

func (h *AuthHandler) Logout(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "logged out successfully"})
}

func (h *AuthHandler) GetProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	var user models.User
	err := h.db.QueryRowContext(c,
		`SELECT user_id, phone_number, legal_name, gender, nationality, kyc_status, kyc_tier, created_at
		 FROM users WHERE user_id = $1`, uid).Scan(
		&user.UserID, &user.PhoneNumber, &user.LegalName, &user.Gender,
		&user.Nationality, &user.KYCStatus, &user.KYCTier, &user.CreatedAt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch profile"})
		return
	}
	c.JSON(http.StatusOK, user)
}

func (h *AuthHandler) SubmitKYC(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	var req models.KYCSubmission
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	nameEnc, nameKey, err := h.encryptPII(req.LegalName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "encryption failed"})
		return
	}

	var passportEnc, passportKey *string
	if req.PassportNumber != "" {
		pe, pk, err := h.encryptPII(req.PassportNumber)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "encryption failed"})
			return
		}
		passportEnc = &pe
		passportKey = &pk
	}

	_, err = h.db.ExecContext(c,
		`UPDATE users SET legal_name = $1, legal_name_encrypted = $2, name_encryption_key = $3,
		 gender = $4, nationality = $5, passport_number = $6, passport_encrypted = $7, passport_encryption_key = $8,
		 id_document_url = $9, kyc_status = 'SUBMITTED', kyc_tier = 1, updated_at = NOW()
		 WHERE user_id = $10`,
		req.LegalName, nameEnc, nameKey, req.Gender, req.Nationality,
		req.PassportNumber, passportEnc, passportKey, req.IDDocumentURL, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to submit KYC"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "KYC submitted successfully", "status": "SUBMITTED"})
}

func (h *AuthHandler) GetKYCStatus(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)
	var status string
	err := h.db.QueryRowContext(c, `SELECT kyc_status FROM users WHERE user_id = $1`, uid).Scan(&status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"kyc_status": status})
}

func (h *AuthHandler) ValidateToken(ctx context.Context, req *pb.ValidateTokenRequest) (*pb.ValidateTokenResponse, error) {
	token, err := jwt.Parse(req.Token, func(token *jwt.Token) (interface{}, error) {
		return []byte(h.cfg.JWTSecret), nil
	})
	if err != nil || !token.Valid {
		return &pb.ValidateTokenResponse{Valid: false}, nil
	}
	claims := token.Claims.(jwt.MapClaims)
	return &pb.ValidateTokenResponse{
		Valid:     true,
		UserId:    claims["sub"].(string),
		Phone:     claims["phone"].(string),
		TokenType: claims["type"].(string),
	}, nil
}
