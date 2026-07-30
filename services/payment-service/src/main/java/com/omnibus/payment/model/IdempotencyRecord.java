package com.omnibus.payment.model;

import lombok.*;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.*;
import java.time.Instant;

@DynamoDbBean
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IdempotencyRecord {
    private String paymentRef;
    private String status;
    private String transactionId;
    private Instant processedAt;
    private String payloadHash;

    @DynamoDbPartitionKey
    public String getPaymentRef() { return paymentRef; }

    @DynamoDbSecondaryPartitionKey(indexNames = "status-index")
    public String getStatus() { return status; }
}
