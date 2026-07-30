package models

import (
	"time"
	"github.com/google/uuid"
)

type User struct {
	UserID             uuid.UUID `db:"user_id" json:"user_id"`
	PhoneNumber        string    `db:"phone_number" json:"phone_number"`
	PhoneEncrypted     string    `db:"phone_encrypted" json:"-"`
	LegalName          *string   `db:"legal_name" json:"legal_name,omitempty"`
	LegalNameEncrypted string    `db:"legal_name_encrypted" json:"-"`
	Gender             *string   `db:"gender" json:"gender,omitempty"`
	Nationality        *string   `db:"nationality" json:"nationality,omitempty"`
	PassportNumber     *string   `db:"passport_number" json:"passport_number,omitempty"`
	PassportEncrypted  string    `db:"passport_encrypted" json:"-"`
	IDDocumentURL      *string   `db:"id_document_url" json:"id_document_url,omitempty"`
	KYCStatus          string    `db:"kyc_status" json:"kyc_status"`
	KYCTier            int       `db:"kyc_tier" json:"kyc_tier"`
	CreatedAt          time.Time `db:"created_at" json:"created_at"`
	UpdatedAt          time.Time `db:"updated_at" json:"updated_at"`
}

type KYCSubmission struct {
	LegalName      string `json:"legal_name" binding:"required,min=2,max=150"`
	Gender         string `json:"gender" binding:"required,oneof=MALE FEMALE OTHER"`
	Nationality    string `json:"nationality" binding:"required,iso3166_1_alpha3"`
	PassportNumber string `json:"passport_number,omitempty"`
	IDDocumentURL  string `json:"id_document_url,omitempty"`
}
