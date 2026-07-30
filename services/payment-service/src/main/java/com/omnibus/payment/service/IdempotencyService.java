package com.omnibus.payment.service;

import com.omnibus.payment.model.IdempotencyRecord;
import com.omnibus.payment.model.PaymentRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.PutItemEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class IdempotencyService {

    private final DynamoDbEnhancedClient dynamoClient;

    public boolean checkAndRecord(String paymentRef, PaymentRequest request) {
        DynamoDbTable<IdempotencyRecord> table = dynamoClient.table("OmniBus_Payment_Idempotency",
                TableSchema.fromBean(IdempotencyRecord.class));

        String payloadHash = hashPayload(request);

        IdempotencyRecord record = IdempotencyRecord.builder()
                .paymentRef(paymentRef)
                .status("PROCESSING")
                .transactionId(UUID.randomUUID().toString())
                .processedAt(Instant.now())
                .payloadHash(payloadHash)
                .build();

        try {
            table.putItem(PutItemEnhancedRequest.builder(IdempotencyRecord.class)
                    .item(record)
                    .conditionExpression(
                        software.amazon.awssdk.enhanced.dynamodb.Expression.builder()
                            .expression("attribute_not_exists(paymentRef)")
                            .build())
                    .build());
            return false; // Not already processed
        } catch (ConditionalCheckFailedException e) {
            log.info("Idempotency check failed for paymentRef: {}", paymentRef);
            return true; // Already processed
        }
    }

    private String hashPayload(PaymentRequest request) {
        return java.util.Base64.getEncoder().encodeToString(
            (request.getBookingId() + request.getAmount() + request.getCurrency() + request.getProvider())
                .getBytes(java.nio.charset.StandardCharsets.UTF_8)
        );
    }
}
