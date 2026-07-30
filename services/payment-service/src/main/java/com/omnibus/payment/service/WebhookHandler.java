package com.omnibus.payment.service;

import com.omnibus.payment.model.PaymentStatus;
import com.omnibus.payment.model.PaymentTransaction;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Instant;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class WebhookHandler {

    private final PaymentTransactionRepository txRepo;
    private final IdempotencyService idempotencyService;
    private final KafkaEventPublisher eventPublisher;

    @Transactional
    public Mono<String> processWebhook(String provider, Map<String, Object> payload, String signature) {
        return Mono.fromCallable(() -> {
            if ("mpesa".equalsIgnoreCase(provider)) {
                return processMpesaWebhook(payload);
            }
            throw new IllegalArgumentException("Unsupported provider: " + provider);
        }).subscribeOn(Schedulers.boundedElastic());
    }

    private String processMpesaWebhook(Map<String, Object> payload) {
        @SuppressWarnings("unchecked")
        Map<String, Object> body = (Map<String, Object>) payload.get("Body");
        @SuppressWarnings("unchecked")
        Map<String, Object> stkCallback = (Map<String, Object>) body.get("stkCallback");

        String checkoutRequestId = (String) stkCallback.get("CheckoutRequestID");
        String resultCode = String.valueOf(stkCallback.get("ResultCode"));
        String resultDesc = (String) stkCallback.get("ResultDesc");
        String merchantRequestId = (String) stkCallback.get("MerchantRequestID");

        // Extract payment ref from metadata
        String paymentRef = extractPaymentRef(stkCallback);

        PaymentTransaction tx = txRepo.findByPaymentRef(paymentRef)
                .orElseThrow(() -> new IllegalStateException("Transaction not found: " + paymentRef));

        if ("0".equals(resultCode)) {
            tx.setStatus(PaymentStatus.PAID);
            tx.setCompletedAt(Instant.now());
            tx.setProviderResponse(resultDesc);
            txRepo.save(tx);

            // Publish TICKET_GENERATE event
            eventPublisher.publishPaymentCompleted(tx);
            log.info("Payment completed for ref: {}", paymentRef);
        } else {
            tx.setStatus(PaymentStatus.FAILED);
            tx.setProviderResponse(resultDesc);
            txRepo.save(tx);
            log.warn("Payment failed for ref: {} - {}", paymentRef, resultDesc);
        }

        return "processed";
    }

    @SuppressWarnings("unchecked")
    private String extractPaymentRef(Map<String, Object> stkCallback) {
        Object callbackMetadata = stkCallback.get("CallbackMetadata");
        if (callbackMetadata instanceof Map) {
            Map<String, Object> meta = (Map<String, Object>) callbackMetadata;
            Object items = meta.get("Item");
            if (items instanceof java.util.List) {
                for (Object item : (java.util.List<?>) items) {
                    if (item instanceof Map) {
                        Map<String, Object> map = (Map<String, Object>) item;
                        if ("AccountReference".equals(map.get("Name"))) {
                            return String.valueOf(map.get("Value"));
                        }
                    }
                }
            }
        }
        return "UNKNOWN";
    }
}
