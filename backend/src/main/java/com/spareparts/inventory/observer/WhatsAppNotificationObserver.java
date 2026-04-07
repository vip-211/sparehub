package com.spareparts.inventory.observer;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.SystemSettingRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class WhatsAppNotificationObserver implements ProductObserver {
    private static final Logger log = LoggerFactory.getLogger(WhatsAppNotificationObserver.class);

    @Autowired
    private SystemSettingRepository systemSettingRepository;

    @Autowired
    private UserRepository userRepository;

    @Override
    public void update(Product product) {
        String enabled = systemSettingRepository.getSettingValue("NOTIF_WHATSAPP_ENABLED", "false");
        if (!"true".equalsIgnoreCase(enabled)) {
            return;
        }

        List<User> users = userRepository.findByDeletedFalse();
        int sentCount = 0;
        
        for (User user : users) {
            if (user.getPhone() != null && !user.getPhone().isEmpty()) {
                // Simulating WhatsApp message sending to each user
                sentCount++;
            }
        }
        log.info("WhatsApp Simulation: Processed alerts for {} users for product: {}", sentCount, product.getName());
    }

    @Override
    public String getObserverName() {
        return "WhatsApp Notification";
    }

    public void sendOfferNotification(Product product) {
        List<User> users = userRepository.findByDeletedFalse();
        int sentCount = 0;

        for (User user : users) {
            if (user.getPhone() != null && !user.getPhone().isEmpty()) {
                // Simulating WhatsApp message sending
                sentCount++;
            }
        }
        log.info("WhatsApp Simulation: Processed offer alerts for {} users for product: {}", sentCount, product.getName());
    }
}
