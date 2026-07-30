package com.omnibus.payment.service;

import com.omnibus.payment.model.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentOrchestrator {

    private final PaymentTransactionRepository txRepo;
    private final IdempotencyService idempotencyService;
    private final MpesaGateway mpesaGateway;
    private final KafkaEventPublisher eventPublisher;

    @Transactional
    public Mono<PaymentResponse> initiatePayment(PaymentRequest request) {
        String paymentRef = generatePaymentRef();

        return Mono.fromCallable(() -> idempotencyService.checkAndRecord(paymentRef, request))
                .subscribeOn(Schedulers.boundedElastic())
                .flatMap(alreadyProcessed -> {
                    if (alreadyProcessed) {
                        log.warn("Duplicate payment request detected: {}", paymentRef);
                        return Mono.error(new IllegalStateException("Payment already processed"));
                    }

                    PaymentTransaction tx = PaymentTransaction.builder()
                            .paymentRef(paymentRef)
                            .bookingId(request.getBookingId())
                            .provider(request.getProvider())
                            .amount(request.getAmount())
                            .currency(request.getCurrency())
                            .status(PaymentStatus.PENDING)
                            .phoneNumber(request.getPhoneNumber())
                            .build();

                    return Mono.fromCallable(() -> txRepo.save(tx))
                            .subscribeOn(Schedulers.boundedElastic())
                            .flatMap(saved -> {
                                if ("MPESA".equals(request.getProvider())) {
                                    return mpesaGateway.initiateSTKPush(saved)
                                            .doOnNext(response -> {
                                                saved.setProviderResponse(response.getRawResponse());
                                                saved.setStatus(PaymentStatus.PROCESSING);
                                                txRepo.save(saved);
                                            })
                                            .map(response -> PaymentResponse.builder()
                                                    .paymentRef(paymentRef)
                                                    .status("PROCESSING")
                                                    .message("STK Push sent to customer")
                                                    .checkoutRequestId(response.getCheckoutRequestId())
                                                    .build());
                                }
                                return Mono.just(PaymentResponse.builder()
                                        .paymentRef(paymentRef)
                                        .status("PENDING")
                                        .message("Payment initiated")
                                        .build());
                            });
                });
    }

    public Mono<PaymentTransaction> getTransactionStatus(String paymentRef) {
        return Mono.fromCallable(() -> txRepo.findByPaymentRef(paymentRef).orElse(null))
                .subscribeOn(Schedulers.boundedElastic());
    }

    private String generatePaymentRef() {
        return "OB" + UUID.randomUUID().toString().replace("-", "").substring(0, 18).toUpperCase();
    }
}
