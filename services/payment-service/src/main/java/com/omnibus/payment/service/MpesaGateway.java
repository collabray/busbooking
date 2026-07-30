package com.omnibus.payment.service;

import com.omnibus.payment.model.PaymentTransaction;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.Instant;
import java.util.Base64;

@Service
@Slf4j
public class MpesaGateway {

    @Value("${mpesa.consumer-key}")
    private String consumerKey;

    @Value("${mpesa.consumer-secret}")
    private String consumerSecret;

    @Value("${mpesa.shortcode}")
    private String shortCode;

    @Value("${mpesa.passkey}")
    private String passKey;

    @Value("${mpesa.base-url}")
    private String baseUrl;

    private final WebClient webClient = WebClient.builder().build();

    public Mono<StkPushResponse> initiateSTKPush(PaymentTransaction tx) {
        String timestamp = java.time.format.DateTimeFormatter.ofPattern("yyyyMMddHHmmss")
                .format(java.time.LocalDateTime.now());
        String password = Base64.getEncoder().encodeToString(
                (shortCode + passKey + timestamp).getBytes());

        StkPushRequest request = new StkPushRequest();
        request.setBusinessShortCode(shortCode);
        request.setPassword(password);
        request.setTimestamp(timestamp);
        request.setTransactionType("CustomerPayBillOnline");
        request.setAmount(tx.getAmount().toString());
        request.setPartyA(tx.getPhoneNumber());
        request.setPartyB(shortCode);
        request.setPhoneNumber(tx.getPhoneNumber());
        request.setCallBackURL("https://api.omnibus.ea/api/v1/payments/webhook/mpesa");
        request.setAccountReference(tx.getPaymentRef());
        request.setTransactionDesc("OmniBus Ticket Payment");

        return getAccessToken()
                .flatMap(token -> webClient.post()
                        .uri(baseUrl + "/mpesa/stkpush/v1/processrequest")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .bodyValue(request)
                        .retrieve()
                        .bodyToMono(StkPushResponse.class)
                        .doOnNext(resp -> log.info("STK Push initiated: {}", resp.getCheckoutRequestId()))
                        .doOnError(e -> log.error("STK Push failed", e)));
    }

    private Mono<String> getAccessToken() {
        String credentials = Base64.getEncoder().encodeToString((consumerKey + ":" + consumerSecret).getBytes());
        return webClient.get()
                .uri(baseUrl + "/oauth/v1/generate?grant_type=client_credentials")
                .header("Authorization", "Basic " + credentials)
                .retrieve()
                .bodyToMono(AccessTokenResponse.class)
                .map(AccessTokenResponse::getAccessToken);
    }

    @Data
    public static class StkPushRequest {
        private String BusinessShortCode;
        private String Password;
        private String Timestamp;
        private String TransactionType;
        private String Amount;
        private String PartyA;
        private String PartyB;
        private String PhoneNumber;
        private String CallBackURL;
        private String AccountReference;
        private String TransactionDesc;
    }

    @Data
    public static class StkPushResponse {
        private String MerchantRequestID;
        private String CheckoutRequestID;
        private String ResponseCode;
        private String ResponseDescription;
        private String CustomerMessage;
        private String rawResponse;
    }

    @Data
    public static class AccessTokenResponse {
        private String access_token;
        private String expires_in;

        public String getAccessToken() { return access_token; }
    }
}
