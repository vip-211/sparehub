package com.spareparts.inventory.controller;

import com.spareparts.inventory.repository.SystemSettingRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import com.spareparts.inventory.entity.SystemSetting;

@RestController
@RequestMapping(value = "/api/settings", produces = "application/json")
@CrossOrigin(origins = "*")
public class SettingsController {

    @Autowired
    private SystemSettingRepository systemSettingRepository;

    @GetMapping("/public")
    public ResponseEntity<List<SystemSetting>> getPublicSettings() {
        return ResponseEntity.ok(systemSettingRepository.findAll().stream()
                .filter(s -> s.getSettingKey().startsWith("ALLOWED_") 
                          || s.getSettingKey().equals("COMPANY_NAME") 
                          || s.getSettingKey().equals("LOGO_URL")
                          || s.getSettingKey().equals("AI_PROVIDER")
                          || s.getSettingKey().equals("AI_CHATBOT_ENABLED"))
                .toList());
    }

    @GetMapping("/loyalty")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, Object>> getLoyaltySettings() {
        String percent = systemSettingRepository.getSettingValue("LOYALTY_PERCENT", "1");
        String minRedeem = systemSettingRepository.getSettingValue("MIN_REDEEM_POINTS", "0");
        return ResponseEntity.ok(Map.of(
                "loyaltyPercent", Integer.parseInt(percent),
                "minRedeemPoints", Long.parseLong(minRedeem)
        ));
    }
}

