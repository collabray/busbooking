package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/omnibus-ea/auth-service/internal/config"
	"github.com/sirupsen/logrus"
)

type WebAuthnHandler struct {
	w        *webauthn.WebAuthn
	db       *sql.DB
	sessions map[string]*webauthn.SessionData
}

func NewWebAuthnHandler(db *sql.DB, cfg *config.Config) *WebAuthnHandler {
	wconfig := &webauthn.Config{
		RPDisplayName: "OmniBus EA Super-Admin",
		RPID:          cfg.WebAuthnRPID,
		RPOrigin:      cfg.WebAuthnOrigin,
		RPIcon:        "https://admin.omnibus.ea/favicon.ico",
		AuthenticatorSelection: protocol.AuthenticatorSelection{
			AuthenticatorAttachment: protocol.Platform,
			UserVerification:        protocol.VerificationRequired,
		},
		AttestationPreference: protocol.PreferDirectAttestation,
	}
	w, err := webauthn.New(wconfig)
	if err != nil {
		logrus.Fatalf("Failed to initialize WebAuthn: %v", err)
	}
	return &WebAuthnHandler{w: w, db: db, sessions: make(map[string]*webauthn.SessionData)}
}

func (h *WebAuthnHandler) BeginRegistration(c *gin.Context) {
	var req struct {
		AdminID string `json:"admin_id" binding:"required,uuid"`
		Email   string `json:"email" binding:"required,email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := &WebAuthnUser{
		id:          []byte(req.AdminID),
		name:        req.Email,
		displayName: req.Email,
	}

	options, session, err := h.w.BeginRegistration(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	h.sessions[req.AdminID] = session
	c.JSON(http.StatusOK, options)
}

func (h *WebAuthnHandler) FinishRegistration(c *gin.Context) {
	var req struct {
		AdminID string `json:"admin_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, ok := h.sessions[req.AdminID]
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "session not found"})
		return
	}

	user := &WebAuthnUser{id: []byte(req.AdminID)}
	response, err := protocol.ParseCredentialCreationResponseBody(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	credential, err := h.w.FinishRegistration(user, *session, response)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	credJSON, _ := json.Marshal(credential)
	_, err = h.db.Exec(`INSERT INTO admin_credentials (admin_id, credential_data, created_at) VALUES ($1, $2, NOW())
		ON CONFLICT (admin_id) DO UPDATE SET credential_data = $2, updated_at = NOW()`,
		req.AdminID, credJSON)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to store credential"})
		return
	}

	delete(h.sessions, req.AdminID)
	c.JSON(http.StatusOK, gin.H{"verified": true, "message": "WebAuthn registration complete"})
}

func (h *WebAuthnHandler) BeginLogin(c *gin.Context) {
	var req struct {
		AdminID string `json:"admin_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var credData []byte
	err := h.db.QueryRow(`SELECT credential_data FROM admin_credentials WHERE admin_id = $1`, req.AdminID).Scan(&credData)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "admin not registered"})
		return
	}

	user := &WebAuthnUser{id: []byte(req.AdminID)}
	var cred webauthn.Credential
	json.Unmarshal(credData, &cred)
	user.credentials = []webauthn.Credential{cred}

	options, session, err := h.w.BeginLogin(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	h.sessions[req.AdminID] = session
	c.JSON(http.StatusOK, options)
}

func (h *WebAuthnHandler) FinishLogin(c *gin.Context) {
	var req struct {
		AdminID string `json:"admin_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, ok := h.sessions[req.AdminID]
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "session not found"})
		return
	}

	var credData []byte
	err := h.db.QueryRow(`SELECT credential_data FROM admin_credentials WHERE admin_id = $1`, req.AdminID).Scan(&credData)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "admin not found"})
		return
	}

	user := &WebAuthnUser{id: []byte(req.AdminID)}
	var cred webauthn.Credential
	json.Unmarshal(credData, &cred)
	user.credentials = []webauthn.Credential{cred}

	response, err := protocol.ParseCredentialRequestResponseBody(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err = h.w.FinishLogin(user, *session, response)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "verification failed"})
		return
	}

	delete(h.sessions, req.AdminID)
	c.JSON(http.StatusOK, gin.H{"verified": true, "message": "WebAuthn login successful"})
}

type WebAuthnUser struct {
	id          []byte
	name        string
	displayName string
	credentials []webauthn.Credential
}

func (u *WebAuthnUser) WebAuthnID() []byte                         { return u.id }
func (u *WebAuthnUser) WebAuthnName() string                       { return u.name }
func (u *WebAuthnUser) WebAuthnDisplayName() string                { return u.displayName }
func (u *WebAuthnUser) WebAuthnIcon() string                       { return "" }
func (u *WebAuthnUser) WebAuthnCredentials() []webauthn.Credential { return u.credentials }
