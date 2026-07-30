package com.omnibus.payment.model;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "payment_transactions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentTransaction {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID transactionId;

    @Column(nullable = false, unique = true, length = 64)
    private String paymentRef;

    @Column(nullable = false)
    private UUID bookingId;

    @Column(nullable = false, length = 20)
    private String provider; // MPESA, AIRTEL_MONEY, TIGO_PESA, MTN, DPO

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(nullable = false, length = 20)
    @Enumerated(EnumType.STRING)
    private PaymentStatus status;

    @Column(length = 500)
    private String providerResponse;

    @Column(length = 100)
    private String phoneNumber;

    @Column(nullable = false)
    private Instant createdAt;

    @Column
    private Instant completedAt;

    @Version
    private Long version;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
    }
}

enum PaymentStatus {
    PENDING, PROCESSING, PAID, FAILED, REFUNDED, CANCELLED
}
