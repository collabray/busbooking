package handlers

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/omnibus-ea/booking-service/internal/config"
	"github.com/omnibus-ea/booking-service/internal/locker"
	pb "github.com/omnibus-ea/booking-service/proto"
	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
)

type BookingHandler struct {
	db      *sql.DB
	redis   *redis.Client
	redlock *locker.Redlock
	cfg     *config.Config
	pb.UnimplementedBookingServiceServer
}

func NewBookingHandler(db *sql.DB, redis *redis.Client, redlock *locker.Redlock, cfg *config.Config) *BookingHandler {
	return &BookingHandler{db: db, redis: redis, redlock: redlock, cfg: cfg}
}

func (h *BookingHandler) LockSeat(c *gin.Context) {
	var req struct {
		ScheduleID string `json:"schedule_id" binding:"required,uuid"`
		SeatNumber   string `json:"seat_number" binding:"required"`
		UserID       string `json:"user_id" binding:"required,uuid"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Verify schedule exists and seat is available
	var busID uuid.UUID
	var capacity int
	var seatLayout string
	err := h.db.QueryRowContext(c,
		`SELECT b.bus_id, b.capacity, b.seat_layout_json 
		 FROM schedules s JOIN buses b ON s.bus_id = b.bus_id 
		 WHERE s.schedule_id = $1 AND s.status = 'SCHEDULED'`, req.ScheduleID).Scan(&busID, &capacity, &seatLayout)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "schedule not found or not active"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}

	// Check if seat is already booked
	var existing int
	err = h.db.QueryRowContext(c,
		`SELECT COUNT(*) FROM bookings WHERE schedule_id = $1 AND seat_number = $2 AND booking_status IN ('HELD', 'BOOKED')`,
		req.ScheduleID, req.SeatNumber).Scan(&existing)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}
	if existing > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "Seat already booked"})
		return
	}

	lockID, acquired, err := h.redlock.AcquireLock(c, busID.String(), req.SeatNumber)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "lock service error"})
		return
	}
	if !acquired {
		c.JSON(http.StatusConflict, gin.H{"error": "Seat currently held by another passenger"})
		return
	}

	// Create HELD booking
	pnr := generatePNR()
	userUUID, _ := uuid.Parse(req.UserID)
	scheduleUUID, _ := uuid.Parse(req.ScheduleID)

	_, err = h.db.ExecContext(c,
		`INSERT INTO bookings (booking_id, pnr_code, user_id, schedule_id, seat_number, passenger_name, amount_paid, currency, payment_status, booking_status, created_at)
		 VALUES ($1, $2, $3, $4, $5, '', 0, 'KES', 'PENDING', 'HELD', NOW())`,
		uuid.New(), pnr, userUUID, scheduleUUID, req.SeatNumber)
	if err != nil {
		h.redlock.ReleaseLock(c, busID.String(), req.SeatNumber, lockID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create booking"})
		return
	}

	// Store lock mapping
	h.redis.Set(c, fmt.Sprintf("booking_lock:%s", pnr), lockID, h.cfg.LockTTL)

	c.JSON(http.StatusOK, gin.H{
		"pnr":        pnr,
		"status":     "HELD",
		"expires_in": h.cfg.LockTTL,
		"lock_id":    lockID,
	})
}

func (h *BookingHandler) ConfirmBooking(c *gin.Context) {
	var req struct {
		PNR        string `json:"pnr" binding:"required,len=10"`
		PassengerName string `json:"passenger_name" binding:"required,min=2"`
		Amount     float64 `json:"amount" binding:"required,gt=0"`
		Currency   string `json:"currency" binding:"required,len=3"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Verify booking is in HELD state
	var bookingID uuid.UUID
	var scheduleID uuid.UUID
	var seatNumber string
	var bookingStatus string
	err := h.db.QueryRowContext(c,
		`SELECT booking_id, schedule_id, seat_number, booking_status FROM bookings WHERE pnr_code = $1`,
		req.PNR).Scan(&bookingID, &scheduleID, &seatNumber, &bookingStatus)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}

	if bookingStatus != "HELD" {
		c.JSON(http.StatusConflict, gin.H{"error": fmt.Sprintf("booking is %s, cannot confirm", bookingStatus)})
		return
	}

	// Update to BOOKED
	_, err = h.db.ExecContext(c,
		`UPDATE bookings SET passenger_name = $1, amount_paid = $2, currency = $3, payment_status = 'PAID', booking_status = 'BOOKED', updated_at = NOW()
		 WHERE booking_id = $4`,
		req.PassengerName, req.Amount, req.Currency, bookingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to confirm booking"})
		return
	}

	// Release Redis lock but keep seat booked in DB
	lockID, _ := h.redis.Get(c, fmt.Sprintf("booking_lock:%s", req.PNR)).Result()
	if lockID != "" {
		var busID uuid.UUID
		h.db.QueryRowContext(c, `SELECT bus_id FROM schedules WHERE schedule_id = $1`, scheduleID).Scan(&busID)
		h.redlock.ReleaseLock(c, busID.String(), seatNumber, lockID)
		h.redis.Del(c, fmt.Sprintf("booking_lock:%s", req.PNR))
	}

	c.JSON(http.StatusOK, gin.H{"pnr": req.PNR, "status": "BOOKED", "message": "Booking confirmed"})
}

func (h *BookingHandler) GetBookingStatus(c *gin.Context) {
	pnr := c.Param("pnr")
	var status string
	var seat string
	var passenger string
	err := h.db.QueryRowContext(c,
		`SELECT booking_status, seat_number, passenger_name FROM bookings WHERE pnr_code = $1`, pnr).Scan(&status, &seat, &passenger)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"pnr": pnr, "status": status, "seat": seat, "passenger": passenger})
}

func (h *BookingHandler) CancelBooking(c *gin.Context) {
	var req struct {
		PNR string `json:"pnr" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var bookingID uuid.UUID
	var scheduleID uuid.UUID
	var seatNumber string
	var status string
	err := h.db.QueryRowContext(c,
		`SELECT booking_id, schedule_id, seat_number, booking_status FROM bookings WHERE pnr_code = $1`, req.PNR).Scan(&bookingID, &scheduleID, &seatNumber, &status)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "booking not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}

	if status == "CANCELLED" {
		c.JSON(http.StatusConflict, gin.H{"error": "booking already cancelled"})
		return
	}

	_, err = h.db.ExecContext(c,
		`UPDATE bookings SET booking_status = 'CANCELLED', payment_status = 'REFUNDED', updated_at = NOW() WHERE booking_id = $1`,
		bookingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to cancel booking"})
		return
	}

	// Release lock if exists
	lockID, _ := h.redis.Get(c, fmt.Sprintf("booking_lock:%s", req.PNR)).Result()
	if lockID != "" {
		var busID uuid.UUID
		h.db.QueryRowContext(c, `SELECT bus_id FROM schedules WHERE schedule_id = $1`, scheduleID).Scan(&busID)
		h.redlock.ReleaseLock(c, busID.String(), seatNumber, lockID)
		h.redis.Del(c, fmt.Sprintf("booking_lock:%s", req.PNR))
	}

	c.JSON(http.StatusOK, gin.H{"pnr": req.PNR, "status": "CANCELLED", "message": "Booking cancelled successfully"})
}

func (h *BookingHandler) GetBookingByPNR(ctx context.Context, req *pb.GetBookingRequest) (*pb.GetBookingResponse, error) {
	var status, seat, passenger string
	var amount float64
	err := h.db.QueryRowContext(ctx,
		`SELECT booking_status, seat_number, passenger_name, amount_paid FROM bookings WHERE pnr_code = $1`,
		req.Pnr).Scan(&status, &seat, &passenger, &amount)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("booking not found")
	}
	if err != nil {
		return nil, err
	}
	return &pb.GetBookingResponse{
		Pnr:       req.Pnr,
		Status:    status,
		Seat:      seat,
		Passenger: passenger,
		Amount:    amount,
	}, nil
}

func generatePNR() string {
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, 10)
	for i := range b {
		b[i] = chars[time.Now().UnixNano()%int64(len(chars))]
		time.Sleep(1 * time.Nanosecond)
	}
	return string(b)
}
