package com.spareparts.inventory.service;

import com.sendgrid.Method;
import com.sendgrid.Request;
import com.sendgrid.Response;
import com.sendgrid.SendGrid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import com.spareparts.inventory.repository.SystemSettingRepository;

@Service
public class EmailService {
    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    private final String apiKey;
    private final String fromEmail;
    private final String defaultOtpMode;
    @Autowired(required = false)
    private SystemSettingRepository systemSettingRepository;

    public EmailService(
            @Value("${sendgrid.api.key:}") String apiKey,
            @Value("${sendgrid.from.email:no-reply@partsmitra.app}") String fromEmail,
            @Value("${otp.mode:EMAIL}") String otpMode) {
        this.apiKey = apiKey;
        this.fromEmail = fromEmail;
        this.defaultOtpMode = otpMode != null ? otpMode.trim().toUpperCase() : "EMAIL";
    }

    public void sendOtp(String email, String otp) {
        String mode = defaultOtpMode;
        try {
            if (systemSettingRepository != null) {
                mode = systemSettingRepository.getSettingValue("OTP_MODE", defaultOtpMode);
            }
        } catch (Exception ignored) {}
        mode = mode != null ? mode.trim().toUpperCase() : "EMAIL";

        if ("LOCAL".equals(mode)) {
            log.info("OTP Mode LOCAL: OTP for {} is {}", email, otp);
            return;
        }
        if (apiKey == null || apiKey.isBlank()) {
            log.error("SENDGRID_API_KEY not configured. Falling back to LOCAL print for {}", email);
            log.info("OTP for {} is {}", email, otp);
            return;
        }
        try {
            SendGrid sg = new SendGrid(apiKey);
            String body = "{\"personalizations\":[{\"to\":[{\"email\":\"" + email + "\"}]}]," +
                    "\"from\":{\"email\":\"" + fromEmail + "\"}," +
                    "\"subject\":\"Your OTP for Parts Mitra\"," +
                    "\"content\":[{\"type\":\"text/plain\",\"value\":\"Your OTP is: " + otp + "\\nValid for 5 minutes.\"}]}";
            Request request = new Request();
            request.setMethod(Method.POST);
            request.setEndpoint("mail/send");
            request.setBody(body);
            Response response = sg.api(request);
            int status = response.getStatusCode();
            if (status >= 200 && status < 300) {
                log.info("SendGrid email sent to {} (status {}).", email, status);
            } else {
                log.error("SendGrid failed for {} (status {}): {}", email, status, response.getBody());
                log.info("Fallback print OTP for {}: {}", email, otp);
            }
        } catch (Exception e) {
            log.error("SendGrid exception for {}: {}", email, e.getMessage(), e);
            log.info("Fallback print OTP for {}: {}", email, otp);
        }
    }
}
