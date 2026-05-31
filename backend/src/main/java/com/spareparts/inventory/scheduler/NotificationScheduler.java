
package com.spareparts.inventory.scheduler;

import com.spareparts.inventory.entity.Cart;
import com.spareparts.inventory.entity.Order;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.CartRepository;
import com.spareparts.inventory.repository.OrderRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.service.FcmService;
import com.spareparts.inventory.service.NotificationTemplateService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;

@Component
@Slf4j
public class NotificationScheduler {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private FcmService fcmService;

    @Autowired
    private NotificationTemplateService notificationTemplateService;

    // Run every day at 10:00 AM IST (since timezone is set to Asia/Kolkata)
    @Scheduled(cron = "0 0 10 * * ?")
    public void sendDailyCartReminders() {
        log.info("NotificationScheduler: Starting daily cart reminders");
        List<User> users = userRepository.findAll();

        for (User user : users) {
            if (user.isDeleted() || user.getStatus() != User.UserStatus.ACTIVE) {
                continue;
            }

            // Check if we've sent a cart notification in the last 24 hours
            if (user.getLastCartNotificationSentAt() != null &&
                ChronoUnit.HOURS.between(user.getLastCartNotificationSentAt(), LocalDateTime.now()) < 24) {
                continue;
            }

            // Check if user has items in cart
            Optional<Cart> cartOpt = cartRepository.findByUserId(user.getId());
            if (cartOpt.isPresent() && !cartOpt.get().getItems().isEmpty()) {
                try {
                    NotificationTemplateService.NotificationMessage message =
                            notificationTemplateService.getRandomMessage(
                                    NotificationTemplateService.NotificationType.CART_REMINDER,
                                    notificationTemplateService.getRandomLanguage());

                    fcmService.sendToUser(user.getId(), message.title(), message.body(), null, null);
                    user.setLastCartNotificationSentAt(LocalDateTime.now());
                    userRepository.save(user);
                    log.info("NotificationScheduler: Sent cart reminder to user {}", user.getId());
                } catch (Exception e) {
                    log.error("NotificationScheduler: Failed to send cart reminder to user {}", user.getId(), e);
                }
            }
        }
        log.info("NotificationScheduler: Completed daily cart reminders");
    }

    // Run every day at 11:00 AM IST for previous order reminders (alternate days)
    @Scheduled(cron = "0 0 11 * * ?")
    public void sendAlternateDayOrderReminders() {
        log.info("NotificationScheduler: Starting alternate day order reminders");
        List<User> users = userRepository.findAll();

        for (User user : users) {
            if (user.isDeleted() || user.getStatus() != User.UserStatus.ACTIVE) {
                continue;
            }

            // Check if we've sent an order notification in the last 48 hours (alternate days)
            if (user.getLastOrderNotificationSentAt() != null &&
                ChronoUnit.HOURS.between(user.getLastOrderNotificationSentAt(), LocalDateTime.now()) < 48) {
                continue;
            }

            // Check if user has any past orders
            List<Order> orders = orderRepository.findByCustomerAndDeletedFalse(user);
            if (!orders.isEmpty()) {
                try {
                    NotificationTemplateService.NotificationMessage message =
                            notificationTemplateService.getRandomMessage(
                                    NotificationTemplateService.NotificationType.PREVIOUS_ORDER_REMINDER,
                                    notificationTemplateService.getRandomLanguage());

                    fcmService.sendToUser(user.getId(), message.title(), message.body(), null, null);
                    user.setLastOrderNotificationSentAt(LocalDateTime.now());
                    userRepository.save(user);
                    log.info("NotificationScheduler: Sent order reminder to user {}", user.getId());
                } catch (Exception e) {
                    log.error("NotificationScheduler: Failed to send order reminder to user {}", user.getId(), e);
                }
            }
        }
        log.info("NotificationScheduler: Completed alternate day order reminders");
    }
}

