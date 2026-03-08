
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.AdminOrderRequest;
import com.spareparts.inventory.dto.OrderDto;
import com.spareparts.inventory.dto.OrderItemDto;
import com.spareparts.inventory.dto.OrderRequest;
import com.spareparts.inventory.entity.Role;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.entity.RoleName;
import com.spareparts.inventory.entity.Notification;
import com.spareparts.inventory.repository.NotificationRepository;
import com.spareparts.inventory.repository.RoleRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
public class AdminController {
    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private OrderService orderService;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @GetMapping("/users")
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @GetMapping("/sales")
    public ResponseEntity<Map<String, Object>> getSalesReport(@RequestParam String type) {
        return ResponseEntity.ok(orderService.getSalesReport(type));
    }

    @DeleteMapping("/users/{userId}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteUser(@PathVariable Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        if (user.getRole() != null && "ROLE_SUPER_MANAGER".equals(user.getRole().getName().name())) {
            return ResponseEntity.status(403).body("Cannot delete SUPER_MANAGER");
        }
        userRepository.delete(user);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/users/delete-bulk")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteUsersBulk(@RequestBody List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return ResponseEntity.ok().build();
        }
        List<User> toDelete = userRepository.findAllById(ids).stream()
                .filter(u -> !(u.getRole() != null && "ROLE_SUPER_MANAGER".equals(u.getRole().getName().name())))
                .collect(Collectors.toList());
        if (!toDelete.isEmpty()) {
            userRepository.deleteAllInBatch(toDelete);
        }
        return ResponseEntity.ok().build();
    }

    @PostMapping("/notifications")
    public ResponseEntity<?> sendNotification(@RequestBody Notification notification) {
        Notification saved = notificationRepository.save(notification);
        
        // Broadcast via WebSocket
        messagingTemplate.convertAndSend("/topic/notifications", saved);
        if (notification.getTargetRole() != null && !"ALL".equals(notification.getTargetRole())) {
            messagingTemplate.convertAndSend("/topic/notifications/" + notification.getTargetRole(), saved);
        }
        
        return ResponseEntity.ok(saved);
    }

    @PutMapping("/users/{userId}/status")
    public ResponseEntity<?> updateUserStatus(@PathVariable Long userId, @RequestParam User.UserStatus status) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setStatus(status);
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/users/{userId}/role")
    public ResponseEntity<?> updateUserRole(@PathVariable Long userId, @RequestParam RoleName roleName) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        Role role = roleRepository.findByName(roleName)
                .orElseThrow(() -> new RuntimeException("Role not found: " + roleName));
        user.setRole(role);
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/orders")
    public ResponseEntity<List<OrderDto>> getAllOrders() {
        return ResponseEntity.ok(orderService.getAllOrders());
    }

    @DeleteMapping("/orders/{orderId}")
    public ResponseEntity<?> deleteOrder(@PathVariable Long orderId) {
        orderService.deleteOrder(orderId);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/orders/{orderId}/items")
    public ResponseEntity<OrderDto> updateOrderItems(@PathVariable Long orderId, @RequestBody List<OrderItemDto> items) {
        return ResponseEntity.ok(orderService.updateOrderItems(orderId, items));
    }

    @PostMapping("/orders")
    public ResponseEntity<OrderDto> createOrder(@Valid @RequestBody AdminOrderRequest orderRequest) {
        return ResponseEntity.ok(orderService.createAdminOrder(orderRequest));
    }
}
