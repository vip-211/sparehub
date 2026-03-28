package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Otp;
import com.spareparts.inventory.repository.OtpRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import com.spareparts.inventory.repository.SystemSettingRepository;
import jakarta.mail.internet.MimeMessage;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

@Service
public class OtpService {

    @Autowired
    private OtpRepository otpRepository;

    @Autowired
    private JavaMailSender mailSender;

    @Autowired
    private SystemSettingRepository systemSettingRepository;

    @Value("${spring.mail.username}")
    private String mailFrom;

    @Value("${mail.provider:SMTP}")
    private String mailProvider;

    @Value("${sendgrid.api.key:}")
    private String sendgridApiKey;

    @Value("${sendgrid.from.email:}")
    private String sendgridFromEmail;

    @Value("${mailgun.api.key:}")
    private String mailgunApiKey;

    @Value("${mailgun.domain:}")
    private String mailgunDomain;

    @Value("${mailgun.from.email:}")
    private String mailgunFromEmail;

    @Value("${brevo.api.key:}")
    private String brevoApiKey;

    @Value("${brevo.from.email:}")
    private String brevoFromEmail;

    @Transactional
    public void saveOtp(String email, String otp) {
        // Keep only the most recent OTP history (max 2) to handle race conditions
        java.util.List<Otp> existing = otpRepository.findAllByEmailOrderByExpiryTimeDesc(email);
        if (existing.size() >= 2) {
            for (int i = 1; i < existing.size(); i++) {
                otpRepository.delete(existing.get(i));
            }
        }
        otpRepository.save(new Otp(email, otp, 5));
    }

    public void sendOtpEmail(String email, String otp) throws Exception {
        String logoUrl = systemSettingRepository.getSettingValue("LOGO_URL", "https://partsmitra.app/logo.png");
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

        if ("SENDGRID".equalsIgnoreCase(mailProvider) && sendgridApiKey != null && !sendgridApiKey.isEmpty()) {
            String from = (sendgridFromEmail != null && !sendgridFromEmail.isEmpty()) ? sendgridFromEmail : mailFrom;
            String body = "{\"personalizations\":[{\"to\":[{\"email\":\"" + email + "\"}]}],\"from\":{\"email\":\"" + from + "\"},\"subject\":\"" + subject + "\","
                    + "\"content\":["
                    + "{\"type\":\"text/plain\",\"value\":\"" + plainText.replace("\n", "\\n") + "\"},"
                    + "{\"type\":\"text/html\",\"value\":\"" + htmlContent.replace("\"", "\\\"").replace("\n", "") + "\"}"
                    + "]}";
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.sendgrid.com/v3/mail/send"))
                    .header("Authorization", "Bearer " + sendgridApiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.ofString());
            return;
        }
        if ("MAILGUN".equalsIgnoreCase(mailProvider) && mailgunApiKey != null && !mailgunApiKey.isEmpty() && mailgunDomain != null && !mailgunDomain.isEmpty()) {
            String from = (mailgunFromEmail != null && !mailgunFromEmail.isEmpty()) ? mailgunFromEmail : mailFrom;
            String form = "from=" + URLEncoder.encode(from, StandardCharsets.UTF_8)
                    + "&to=" + URLEncoder.encode(email, StandardCharsets.UTF_8)
                    + "&subject=" + URLEncoder.encode(subject, StandardCharsets.UTF_8)
                    + "&text=" + URLEncoder.encode(plainText, StandardCharsets.UTF_8)
                    + "&html=" + URLEncoder.encode(htmlContent, StandardCharsets.UTF_8);
            String auth = "Basic " + Base64.getEncoder().encodeToString(("api:" + mailgunApiKey).getBytes(StandardCharsets.UTF_8));
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.mailgun.net/v3/" + mailgunDomain + "/messages"))
                    .header("Authorization", auth)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(form))
                    .build();
            HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.ofString());
            return;
        }
        if ("BREVO".equalsIgnoreCase(mailProvider) && brevoApiKey != null && !brevoApiKey.isEmpty()) {
            String from = (brevoFromEmail != null && !brevoFromEmail.isEmpty()) ? brevoFromEmail : mailFrom;
            String body = "{\"sender\":{\"email\":\"" + from + "\"},\"to\":[{\"email\":\"" + email + "\"}],\"subject\":\"" + subject + "\",\"htmlContent\":\"" + htmlContent.replace("\"", "\\\"").replace("\n", "") + "\"}";
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.brevo.com/v3/smtp/email"))
                    .header("api-key", brevoApiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.ofString());
            return;
        }
        if ("NONE".equalsIgnoreCase(mailProvider)) {
            return;
        }
        
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        helper.setFrom(mailFrom);
        helper.setTo(email);
        helper.setSubject(subject);
        helper.setText(plainText, htmlContent);
        mailSender.send(message);
    }
}
