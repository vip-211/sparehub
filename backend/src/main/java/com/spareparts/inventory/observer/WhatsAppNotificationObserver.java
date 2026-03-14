package com.spareparts.inventory.observer;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.SystemSettingRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class WhatsAppNotificationObserver implements ProductObserver {

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
        
        String message = "New Spare Part Alert! \n" +
                         "Name: " + product.getName() + "\n" +
                         "Part No: " + product.getPartNumber() + "\n" +
                         "Check it out in Spares Hub!";

        for (User user : users) {
            if (user.getPhone() != null && !user.getPhone().isEmpty()) {
                // Simulating WhatsApp message sending to each user
                System.out.println("[WHATSAPP SENT TO " + user.getPhone() + "]: " + message);
            }
        }
    }

    @Override
    public String getObserverName() {
        return "WhatsApp Notification";
    }
}
