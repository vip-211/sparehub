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
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@Slf4j
public class FcmService {

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    public void sendToUser(Long userId, String title, String message, String offerType, String imageUrl) {
        log.info("FcmService: Preparing to send notification to user {}: {}", userId, title);
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
            log.warn("FcmService: Firebase not initialized, skipping FCM notification for user {}", userId);
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
                    String response = FirebaseMessaging.getInstance().send(fcmMessage);
                    log.info("FcmService: Successfully sent FCM to user {}. Response: {}", userId, response);
                } catch (FirebaseMessagingException e) {
                    log.error("FcmService: Error sending FCM message to user {}: {}", userId, e.getMessage());
                }
            } else {
                log.warn("FcmService: No FCM token for user {}", userId);
            }
        }, () -> log.error("FcmService: User not found: {}", userId));
    }

    public void sendBroadcast(String title, String message, String offerType, String imageUrl) {
        log.info("FcmService: Preparing broadcast notification: {}", title);
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
            log.warn("FcmService: Firebase not initialized, skipping FCM broadcast.");
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
            String response = FirebaseMessaging.getInstance().send(fcmMessage);
            log.info("FcmService: Successfully sent FCM broadcast to all-users topic. Response: {}", response);
        } catch (FirebaseMessagingException e) {
            log.error("FcmService: Error sending FCM broadcast: {}", e.getMessage());
        }
    }

    public void sendToRole(String role, String title, String message, String offerType, String imageUrl) {
        log.info("FcmService: Preparing notification for role {}: {}", role, title);
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
            log.warn("FcmService: Firebase not initialized, skipping FCM role notification.");
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
            String response = FirebaseMessaging.getInstance().send(fcmMessage);
            log.info("FcmService: Successfully sent FCM role message to topic role-{}. Response: {}", role, response);
        } catch (FirebaseMessagingException e) {
            log.error("FcmService: Error sending FCM role message: {}", e.getMessage());
        }
    }

    public void sendOrderStatusToUser(Long userId, Long orderId, String title, String message) {
        log.info("FcmService: Preparing order status notification for user {}: {}", userId, title);
        // Save for in-app log
        saveNotification(userId, title, message, false, null);
        // WebSocket to user queue
        Map<String, Object> payload = new HashMap<>();
        payload.put("title", title);
        payload.put("message", message);
        payload.put("orderId", orderId);
        messagingTemplate.convertAndSendToUser(userId.toString(), "/queue/orders", payload);

        if (FirebaseApp.getApps().isEmpty()) {
            log.warn("FcmService: Firebase not initialized, skipping order status FCM.");
            return;
        }
        userRepository.findById(userId).ifPresentOrElse(user -> {
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
                    String response = FirebaseMessaging.getInstance().send(msg);
                    log.info("FcmService: Successfully sent order status FCM to user {}. Response: {}", userId, response);
                } catch (FirebaseMessagingException e) {
                    log.error("FcmService: Error sending order status FCM to user {}: {}", userId, e.getMessage());
                }
            } else {
                log.warn("FcmService: No FCM token for user {}", userId);
            }
        }, () -> log.error("FcmService: User not found for order status: {}", userId));
    }

    public void sendToAdminAndSuperManager(String title, String message, Map<String, String> data) {
        // 1. Send to ADMIN role
        sendToRole("ROLE_ADMIN", title, message, null, null);
        // 2. Send to SUPER_MANAGER role
        sendToRole("ROLE_SUPER_MANAGER", title, message, null, null);
    }
    
    public void sendOrderStatusToStaff(Long orderId, String title, String message) {
        log.info("FcmService: Preparing order status notification for staff: {}", title);
        // Broadcast to all staff via topic and role channel, include route so notifications are clickable
        // Save log as role-targeted message
        saveNotification(null, title, message, false, "ROLE_STAFF");
        
        Map<String, Object> payload = new HashMap<>();
        payload.put("title", title);
        payload.put("message", message);
        payload.put("orderId", orderId);
        messagingTemplate.convertAndSend("/topic/notifications/ROLE_STAFF", payload);
        
        if (FirebaseApp.getApps().isEmpty()) {
            log.warn("FcmService: Firebase not initialized, skipping staff notification.");
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
            String response = FirebaseMessaging.getInstance().send(msg);
            log.info("FcmService: Successfully sent staff order status FCM. Response: {}", response);
        } catch (FirebaseMessagingException e) {
            log.error("FcmService: Error sending staff order status FCM: {}", e.getMessage());
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
