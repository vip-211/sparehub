package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Otp;
import com.spareparts.inventory.repository.OtpRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OtpService {

    @Autowired
    private OtpRepository otpRepository;

    @Autowired
    private JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String mailFrom;

    @Transactional
    public void saveOtp(String email, String otp) {
        otpRepository.deleteByEmail(email);
        otpRepository.save(new Otp(email, otp, 5)); // Valid for 5 mins
    }

    public void sendOtpEmail(String email, String otp) throws Exception {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(mailFrom);
        message.setTo(email);
        message.setSubject("Your OTP for Parts Mitra");
        message.setText("Your OTP is: " + otp + "\n\nThis OTP is valid for 5 minutes.");
        mailSender.send(message);
    }
}
