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
                         "Check it out in Parts Mitra!";

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

    public void sendOfferNotification(Product product) {
        List<User> users = userRepository.findByDeletedFalse();
        String offerType = product.getOfferType().name().toLowerCase();
        
        String message = "🔥 NEW " + offerType.toUpperCase() + " OFFER! 🔥\n" +
                         "Product: " + product.getName() + "\n" +
                         "Check out this special offer in Parts Mitra now!";

        for (User user : users) {
            if (user.getPhone() != null && !user.getPhone().isEmpty()) {
                // Simulating WhatsApp message sending
                System.out.println("[WHATSAPP SENT TO " + user.getPhone() + "]: " + message);
            }
        }
    }
}
