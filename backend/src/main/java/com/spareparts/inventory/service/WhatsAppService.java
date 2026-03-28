package com.spareparts.inventory.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

@Service
public class WhatsAppService {
    private static final Logger log = LoggerFactory.getLogger(WhatsAppService.class);

    @Value("${whatsapp.api.token:}")
    private String apiToken;

    @Value("${whatsapp.phone.number.id:}")
    private String phoneNumberId;

    @Value("${whatsapp.template.name:otp_template}")
    private String templateName;

    public void sendOtp(String phone, String otp) throws Exception {
        if (apiToken == null || apiToken.isEmpty() || phoneNumberId == null || phoneNumberId.isEmpty()) {
            log.warn("WhatsApp API credentials not configured. Skipping message to {}", phone);
            return;
        }

        // Meta requires phone number without '+' and with country code
        String formattedPhone = phone.replaceAll("\\D", "");
        
        log.info("Sending WhatsApp OTP to {}", formattedPhone);

        String url = "https://graph.facebook.com/v18.0/" + phoneNumberId + "/messages";

        String body = "{" +
                "  \"messaging_product\": \"whatsapp\"," +
                "  \"to\": \"" + formattedPhone + "\"," +
                "  \"type\": \"template\"," +
                "  \"template\": {" +
                "    \"name\": \"" + templateName + "\"," +
                "    \"language\": { \"code\": \"en\" }," +
                "    \"components\": [{" +
                "      \"type\": \"body\"," +
                "      \"parameters\": [{" +
                "        \"type\": \"text\"," +
                "        \"text\": \"" + otp + "\"" +
                "      }]" +
                "    }]" +
                "  }" +
                "}";

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer " + apiToken)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        HttpResponse<String> response = HttpClient.newHttpClient()
                .send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() >= 200 && response.statusCode() < 300) {
            log.info("WhatsApp OTP sent successfully to {}. Response: {}", formattedPhone, response.body());
        } else {
            log.error("Failed to send WhatsApp OTP to {}. Status: {}, Response: {}", 
                    formattedPhone, response.statusCode(), response.body());
            throw new RuntimeException("WhatsApp API error: " + response.body());
        }
    }
}
