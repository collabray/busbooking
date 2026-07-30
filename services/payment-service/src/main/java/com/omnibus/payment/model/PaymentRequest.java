package com.omnibus.payment.model;

import jakarta.validation.constraints.*;
import lombok.Data;
import java.math.BigDecimal;
import java.util.UUID;

@Data
public class PaymentRequest {
    @NotNull
    private UUID bookingId;

    @NotBlank
    @Pattern(regexp = "^(MPESA|AIRTEL_MONEY|TIGO_PESA|MTN|DPO)$")
    private String provider;

    @NotNull
    @DecimalMin("0.01")
    private BigDecimal amount;

    @NotBlank
    @Size(min = 3, max = 3)
    private String currency;

    @NotBlank
    @Pattern(regexp = "^\+?[1-9]\d{1,14}$")
    private String phoneNumber;
}
