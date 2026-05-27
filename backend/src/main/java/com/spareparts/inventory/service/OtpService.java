package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Otp;
import com.spareparts.inventory.repository.OtpRepository;
import com.spareparts.inventory.repository.SystemSettingRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
public class OtpService {

    @Autowired
    private OtpRepository otpRepository;

    @Autowired
    private BrevoMailService brevoMailService;

    @Autowired
    private SystemSettingRepository systemSettingRepository;

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

    public void sendOtp(String identifier, String otp) throws Exception {
        // If identifier is provided, we try to detect if it's email or phone
        if (identifier == null || identifier.isEmpty()) return;

        if (identifier.contains("@")) {
            // It's an email, send email
            log.info("Sending OTP via Email to {}", identifier);
            sendOtpEmail(identifier, otp);
        } else {
            // It's likely a phone number, which is now handled by Firebase client-side
            log.info("Phone identifier {} detected. Backend skipping OTP send (delegated to Firebase).", identifier);
        }
    }

    public void sendOtpEmail(String email, String otp) throws Exception {
        log.info("**************************************************");
        log.info("OTP GENERATED FOR {}: {}", email, otp);
        log.info("**************************************************");
        
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

        try {
            brevoMailService.sendEmail(email, subject, htmlContent, plainText);
        } catch (Exception e) {
            log.error("CRITICAL: Failed to send OTP email to {}. Error: {}", email, e.getMessage());
            log.info("PLEASE USE THE OTP FROM THE LOGS ABOVE TO PROCEED.");
            throw e;
        }
    }
}
