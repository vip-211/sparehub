package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Otp;
import com.spareparts.inventory.repository.OtpRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
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
        if ("SENDGRID".equalsIgnoreCase(mailProvider) && sendgridApiKey != null && !sendgridApiKey.isEmpty()) {
            String from = (sendgridFromEmail != null && !sendgridFromEmail.isEmpty()) ? sendgridFromEmail : mailFrom;
            String body = "{\"personalizations\":[{\"to\":[{\"email\":\"" + email + "\"}]}],\"from\":{\"email\":\"" + from + "\"},\"subject\":\"Your OTP for Parts Mitra\",\"content\":[{\"type\":\"text/plain\",\"value\":\"Your OTP is: " + otp + "\\n\\nThis OTP is valid for 5 minutes.\"}]}";
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
                    + "&subject=" + URLEncoder.encode("Your OTP for Parts Mitra", StandardCharsets.UTF_8)
                    + "&text=" + URLEncoder.encode("Your OTP is: " + otp + "\n\nThis OTP is valid for 5 minutes.", StandardCharsets.UTF_8);
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
            String body = "{\"sender\":{\"email\":\"" + from + "\"},\"to\":[{\"email\":\"" + email + "\"}],\"subject\":\"Your OTP for Parts Mitra\",\"textContent\":\"Your OTP is: " + otp + "\\n\\nThis OTP is valid for 5 minutes.\"}";
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
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(mailFrom);
        message.setTo(email);
        message.setSubject("Your OTP for Parts Mitra");
        message.setText("Your OTP is: " + otp + "\n\nThis OTP is valid for 5 minutes.");
        mailSender.send(message);
    }
}
