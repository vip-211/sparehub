package com.spareparts.inventory.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.spareparts.inventory.entity.Notification;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.NotificationRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class FcmService {

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    public void sendToUser(Long userId, String title, String message, String offerType, String imageUrl) {
        // Always save for in-app notifications
        Notification notification = saveNotification(userId, title, message, false, null);

        // Push to WebSocket for real-time in-app delivery
        Map<String, Object> payload = new HashMap<>();
        payload.put("id", notification.getId());
        payload.put("title", title);
        payload.put("message", message);
        payload.put("createdAt", notification.getCreatedAt());
        messagingTemplate.convertAndSendToUser(userId.toString(), "/queue/notifications", payload);

        if (FirebaseApp.getApps().isEmpty()) {
            System.out.println("FcmService: Firebase not initialized, skipping FCM notification for user " + userId);
            return;
        }
        userRepository.findById(userId).ifPresentOrElse(user -> {
            if (user.getFcmToken() != null && !user.getFcmToken().isEmpty()) {
                String roleName = "ROLE_MECHANIC";
                if (user.getRole() != null && user.getRole().getName() != null) {
                    roleName = user.getRole().getName().name();
                }
                Message fcmMessage = Message.builder()
                        .setToken(user.getFcmToken())
                        .setNotification(com.google.firebase.messaging.Notification.builder()
                                .setTitle(title)
                                .setBody(message)
                                .build())
                        .setAndroidConfig(AndroidConfig.builder()
                                .setPriority(AndroidConfig.Priority.HIGH)
                                .setNotification(AndroidNotification.builder()
                                        .setChannelId("spare_parts_channel")
                                        .build())
                                .build())
                        .putData("route", "offers")
                        .putData("offerType", offerType != null ? offerType : "")
                        .putData("role", roleName)
                        .putData("title", title != null ? title : "")
                        .putData("message", message != null ? message : "")
                        .putData("imageUrl", imageUrl != null ? imageUrl : "")
                        .build();

                try {
                    FirebaseMessaging.getInstance().send(fcmMessage);
                    System.out.println("FcmService: Successfully sent FCM to user " + userId);
                } catch (FirebaseMessagingException e) {
                    System.err.println("FcmService: Error sending FCM message to user " + userId + ": " + e.getMessage());
                }
            } else {
                System.out.println("FcmService: No FCM token for user " + userId);
            }
        }, () -> System.out.println("FcmService: User not found: " + userId));
    }

    public void sendBroadcast(String title, String message, String offerType, String imageUrl) {
        // Always save for in-app notifications
        Notification notification = saveNotification(null, title, message, true, "ALL");

        // Push to WebSocket for real-time in-app delivery
        Map<String, Object> payload = new HashMap<>();
        payload.put("id", notification.getId());
        payload.put("title", title);
        payload.put("message", message);
        payload.put("createdAt", notification.getCreatedAt());
        messagingTemplate.convertAndSend("/topic/notifications", payload);

        if (FirebaseApp.getApps().isEmpty()) {
            System.out.println("FcmService: Firebase not initialized, skipping FCM broadcast.");
            return;
        }
        com.google.firebase.messaging.Notification fcmNotification = com.google.firebase.messaging.Notification.builder()
                .setTitle(title)
                .setBody(message)
                .build();

        // Using topics for broadcast
        Message fcmMessage = Message.builder()
                .setTopic("all-users")
                .setNotification(fcmNotification)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId("spare_parts_channel")
                                .build())
                        .build())
                .putData("route", "offers")
                .putData("offerType", offerType != null ? offerType : "")
                .putData("role", "ALL")
                .putData("title", title != null ? title : "")
                .putData("message", message != null ? message : "")
                .putData("imageUrl", imageUrl != null ? imageUrl : "")
                .build();

        try {
            FirebaseMessaging.getInstance().send(fcmMessage);
            System.out.println("FcmService: Successfully sent FCM broadcast to all-users topic");
        } catch (FirebaseMessagingException e) {
            System.err.println("FcmService: Error sending FCM broadcast: " + e.getMessage());
        }
    }

    public void sendToRole(String role, String title, String message, String offerType, String imageUrl) {
        // Always save for in-app notifications
        Notification notification = saveNotification(null, title, message, false, role);

        // Push to WebSocket for real-time in-app delivery
        Map<String, Object> payload = new HashMap<>();
        payload.put("id", notification.getId());
        payload.put("title", title);
        payload.put("message", message);
        payload.put("createdAt", notification.getCreatedAt());
        messagingTemplate.convertAndSend("/topic/notifications/" + role, payload);

        if (FirebaseApp.getApps().isEmpty()) {
            System.out.println("FcmService: Firebase not initialized, skipping FCM role notification.");
            return;
        }
        // Alternatively, use topics per role
        Message fcmMessage = Message.builder()
                .setTopic("role-" + role)
                .setNotification(com.google.firebase.messaging.Notification.builder()
                        .setTitle(title)
                        .setBody(message)
                        .build())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId("spare_parts_channel")
                                .build())
                        .build())
                .putData("route", "offers")
                .putData("offerType", offerType != null ? offerType : "")
                .putData("role", role)
                .putData("title", title != null ? title : "")
                .putData("message", message != null ? message : "")
                .putData("imageUrl", imageUrl != null ? imageUrl : "")
                .build();

        try {
            FirebaseMessaging.getInstance().send(fcmMessage);
        } catch (FirebaseMessagingException e) {
            System.err.println("FcmService: Error sending FCM role message: " + e.getMessage());
        }
    }

    public void sendOrderStatusToUser(Long userId, Long orderId, String title, String message) {
        // Save for in-app log
        saveNotification(userId, title, message, false, null);
        // WebSocket to user queue
        Map<String, Object> payload = new HashMap<>();
        payload.put("title", title);
        payload.put("message", message);
        payload.put("orderId", orderId);
        messagingTemplate.convertAndSendToUser(userId.toString(), "/queue/orders", payload);

        if (FirebaseApp.getApps().isEmpty()) {
            return;
        }
        userRepository.findById(userId).ifPresent(user -> {
            if (user.getFcmToken() != null && !user.getFcmToken().isEmpty()) {
                String roleName = "ROLE_MECHANIC";
                if (user.getRole() != null && user.getRole().getName() != null) {
                    roleName = user.getRole().getName().name();
                }
                Message msg = Message.builder()
                        .setToken(user.getFcmToken())
                        .setNotification(com.google.firebase.messaging.Notification.builder()
                                .setTitle(title)
                                .setBody(message)
                                .build())
                        .setAndroidConfig(AndroidConfig.builder()
                                .setPriority(AndroidConfig.Priority.HIGH)
                                .setNotification(AndroidNotification.builder()
                                        .setChannelId("spare_parts_channel")
                                        .build())
                                .build())
                        .putData("route", "orders")
                        .putData("orderId", orderId != null ? String.valueOf(orderId) : "")
                        .putData("role", roleName)
                        .putData("title", title != null ? title : "")
                        .putData("message", message != null ? message : "")
                        .build();
                try {
                    FirebaseMessaging.getInstance().send(msg);
                } catch (FirebaseMessagingException e) {
                    System.err.println("FcmService: Error sending order status FCM: " + e.getMessage());
                }
            }
        });
    }

    public void sendToAdminAndSuperManager(String title, String message, Map<String, String> data) {
        // 1. Send to ADMIN role
        sendToRole("ROLE_ADMIN", title, message, null, null);
        // 2. Send to SUPER_MANAGER role
        sendToRole("ROLE_SUPER_MANAGER", title, message, null, null);
        
        // Also push via standard WebSocket /topic/orders if needed (though already handled in OrderService usually)
    }
    
    public void sendOrderStatusToStaff(Long orderId, String title, String message) {
        // Broadcast to all staff via topic and role channel, include route so notifications are clickable
        // Save log as role-targeted message
        saveNotification(null, title, message, false, "ROLE_STAFF");
        
        Map<String, Object> payload = new HashMap<>();
        payload.put("title", title);
        payload.put("message", message);
        payload.put("orderId", orderId);
        messagingTemplate.convertAndSend("/topic/notifications/ROLE_STAFF", payload);
        
        if (FirebaseApp.getApps().isEmpty()) {
            return;
        }
        Message msg = Message.builder()
                .setTopic("role-ROLE_STAFF")
                .setNotification(com.google.firebase.messaging.Notification.builder()
                        .setTitle(title)
                        .setBody(message)
                        .build())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId("spare_parts_channel")
                                .build())
                        .build())
                .putData("route", "orders")
                .putData("orderId", orderId != null ? String.valueOf(orderId) : "")
                .putData("role", "ROLE_STAFF")
                .putData("title", title != null ? title : "")
                .putData("message", message != null ? message : "")
                .build();
        try {
            FirebaseMessaging.getInstance().send(msg);
        } catch (FirebaseMessagingException e) {
            System.err.println("FcmService: Error sending staff order status FCM: " + e.getMessage());
        }
    }

    private Notification saveNotification(Long userId, String title, String message, boolean isBroadcast, String targetRole) {
        Notification notification = new Notification();
        notification.setTitle(title);
        notification.setMessage(message);
        notification.setUserId(userId);
        notification.setIsBroadcast(isBroadcast);
        notification.setTargetRole(targetRole);
        return notificationRepository.save(notification);
    }
}
