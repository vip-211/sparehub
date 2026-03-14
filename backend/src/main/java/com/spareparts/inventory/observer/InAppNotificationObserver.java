package com.spareparts.inventory.observer;

import com.spareparts.inventory.entity.Notification;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.NotificationRepository;
import com.spareparts.inventory.repository.SystemSettingRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

@Component
public class InAppNotificationObserver implements ProductObserver {

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Autowired
    private SystemSettingRepository systemSettingRepository;

    @Override
    public void update(Product product) {
        String enabled = systemSettingRepository.getSettingValue("NOTIF_IN_APP_ENABLED", "true");
        if (!"true".equalsIgnoreCase(enabled)) {
            return;
        }

        Notification notification = new Notification();
        notification.setTitle("New Product Launched!");
        notification.setMessage("Check out our new product: " + product.getName() + " (Part No: " + product.getPartNumber() + ")");
        notification.setTargetRole("ALL");

        notificationRepository.save(notification);
        
        // Broadcast via WebSocket
        messagingTemplate.convertAndSend("/topic/notifications", notification);
    }

    @Override
    public String getObserverName() {
        return "In-App Notification";
    }
}
