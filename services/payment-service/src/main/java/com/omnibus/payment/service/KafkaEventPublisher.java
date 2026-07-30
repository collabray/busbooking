package com.omnibus.payment.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.omnibus.payment.model.PaymentTransaction;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class KafkaEventPublisher {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;

    @SneakyThrows
    public void publishPaymentCompleted(PaymentTransaction tx) {
        Map<String, Object> event = Map.of(
            "event_type", "PAYMENT_COMPLETED",
            "payment_ref", tx.getPaymentRef(),
            "booking_id", tx.getBookingId(),
            "amount", tx.getAmount(),
            "currency", tx.getCurrency(),
            "provider", tx.getProvider(),
            "timestamp", tx.getCompletedAt().toString()
        );
        String message = objectMapper.writeValueAsString(event);
        kafkaTemplate.send("payment.completed", tx.getPaymentRef(), message)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish payment event", ex);
                    } else {
                        log.info("Payment event published: {}", tx.getPaymentRef());
                    }
                });
    }
}
