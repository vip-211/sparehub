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
        if (fromEmail == null || fromEmail.isBlank()) {
            log.error("SendGrid FROM email is not configured (sendgrid.from.email is blank).");
            throw new IllegalStateException("SendGrid FROM email is not configured");
        }
        if (apiKey == null || apiKey.isBlank()) {
            log.error("SENDGRID_API_KEY not configured. Falling back to LOCAL print for {}", email);
            log.info("OTP for {} is {}", email, otp);
            return;
        }
        try {
            SendGrid sg = new SendGrid(apiKey);
            log.info("Sending OTP email via SendGrid. FROM: {}, TO: {}", fromEmail, email);
            
            String logoUrl = systemSettingRepository != null 
                ? systemSettingRepository.getSettingValue("LOGO_URL", "https://partsmitra.app/logo.png")
                : "https://partsmitra.app/logo.png";
                
            String subject = "Your OTP for Parts Mitra";
            
            String plainText = "Hello,\n\n"
                    + "Your One-Time Password (OTP) for Parts Mitra is: " + otp + "\n\n"
                    + "This code is valid for 5 minutes. For security reasons, please do not share this OTP with anyone.\n\n"
                    + "If you did not request this code, please ignore this email.\n\n"
                    + "Best regards,\n"
                    + "Parts Mitra Team";

            String htmlContent = "<html><body style='font-family: Arial, sans-serif; color: #333; line-height: 1.6;'>"
                    + "<div style='max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;'>"
                    + "<div style='text-align: center; margin-bottom: 20px;'>"
                    + "<img src='" + logoUrl + "' alt='Parts Mitra Logo' style='max-width: 150px; height: auto;' />"
                    + "</div>"
                    + "<h2 style='color: #4f46e5; text-align: center;'>Your One-Time Password</h2>"
                    + "<p>Hello,</p>"
                    + "<p>Your One-Time Password (OTP) for Parts Mitra is:</p>"
                    + "<div style='text-align: center; margin: 30px 0;'>"
                    + "<span style='font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #4f46e5; padding: 10px 20px; background: #f3f4f6; border-radius: 5px;'>" + otp + "</span>"
                    + "</div>"
                    + "<p>This code is valid for <strong>5 minutes</strong>. For security reasons, please do not share this OTP with anyone.</p>"
                    + "<p>If you did not request this code, please ignore this email.</p>"
                    + "<hr style='border: none; border-top: 1px solid #eee; margin: 20px 0;' />"
                    + "<p style='font-size: 12px; color: #999; text-align: center;'>Best regards,<br />Parts Mitra Team</p>"
                    + "</div>"
                    + "</body></html>";

            String body = "{\"personalizations\":[{\"to\":[{\"email\":\"" + email + "\"}]}]," +
                    "\"from\":{\"email\":\"" + fromEmail + "\"}," +
                    "\"subject\":\"" + subject + "\"," +
                    "\"content\":[" +
                    "{\"type\":\"text/plain\",\"value\":\"" + plainText.replace("\n", "\\n") + "\"}," +
                    "{\"type\":\"text/html\",\"value\":\"" + htmlContent.replace("\"", "\\\"").replace("\n", "") + "\"}" +
                    "]}";
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
