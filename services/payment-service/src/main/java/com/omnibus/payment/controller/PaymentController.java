package com.omnibus.payment.controller;

import com.omnibus.payment.model.*;
import com.omnibus.payment.service.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentController {

    private final PaymentOrchestrator orchestrator;
    private final WebhookHandler webhookHandler;

    @PostMapping("/initiate")
    public Mono<ResponseEntity<PaymentResponse>> initiatePayment(@Valid @RequestBody PaymentRequest request) {
        log.info("Initiating payment for booking: {}, provider: {}", request.getBookingId(), request.getProvider());
        return orchestrator.initiatePayment(request)
                .map(ResponseEntity::ok)
                .onErrorResume(e -> {
                    log.error("Payment initiation failed", e);
                    return Mono.just(ResponseEntity.badRequest().body(
                        PaymentResponse.builder().status("FAILED").message(e.getMessage()).build()
                    ));
                });
    }

    @PostMapping("/webhook/{provider}")
    public Mono<ResponseEntity<Map<String, String>>> handleWebhook(
            @PathVariable String provider,
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-Signature", required = false) String signature) {
        log.info("Webhook received from provider: {}", provider);
        return webhookHandler.processWebhook(provider, payload, signature)
                .map(result -> ResponseEntity.ok(Map.of("status", "processed")))
                .onErrorResume(e -> {
                    log.error("Webhook processing failed", e);
                    return Mono.just(ResponseEntity.badRequest().body(Map.of("status", "error", "message", e.getMessage())));
                });
    }

    @GetMapping("/{paymentRef}/status")
    public Mono<ResponseEntity<PaymentTransaction>> getStatus(@PathVariable String paymentRef) {
        return orchestrator.getTransactionStatus(paymentRef)
                .map(ResponseEntity::ok)
                .defaultIfEmpty(ResponseEntity.notFound().build());
    }
}
