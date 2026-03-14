
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.AdminOrderRequest;
import com.spareparts.inventory.dto.OrderDto;
import com.spareparts.inventory.dto.OrderItemDto;
import com.spareparts.inventory.dto.OrderRequest;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.entity.Role;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.entity.RoleName;
import com.spareparts.inventory.entity.Notification;
import com.spareparts.inventory.entity.Order;
import com.spareparts.inventory.entity.SystemSetting;
import com.spareparts.inventory.repository.NotificationRepository;
import com.spareparts.inventory.repository.RoleRepository;
import com.spareparts.inventory.repository.SystemSettingRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.service.OrderService;
import com.spareparts.inventory.service.ProductService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import com.spareparts.inventory.security.UserDetailsImpl;
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
    private ProductService productService;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private SystemSettingRepository systemSettingRepository;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @GetMapping("/settings")
    public ResponseEntity<List<SystemSetting>> getAllSettings() {
        return ResponseEntity.ok(systemSettingRepository.findAll());
    }

    @PostMapping("/settings")
    public ResponseEntity<?> updateSetting(@RequestBody SystemSetting setting) {
        return ResponseEntity.ok(systemSettingRepository.save(setting));
    }

    @PostMapping("/settings/bulk")
    public ResponseEntity<?> updateSettingsBulk(@RequestBody List<SystemSetting> settings) {
        return ResponseEntity.ok(systemSettingRepository.saveAll(settings));
    }

    @GetMapping("/users")
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findByDeletedFalse());
    }

    @GetMapping("/recycle-bin/users")
    public ResponseEntity<List<User>> getDeletedUsers() {
        return ResponseEntity.ok(userRepository.findByDeletedTrue());
    }

    @PostMapping("/recycle-bin/users/{userId}/restore")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> restoreUser(@PathVariable Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setDeleted(false);
        userRepository.save(user);
        return ResponseEntity.ok().build();
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
        user.setDeleted(true);
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/users/delete-bulk")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteUsersBulk(@RequestBody List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return ResponseEntity.ok().build();
        }
        List<User> users = userRepository.findAllById(ids).stream()
                .filter(u -> !(u.getRole() != null && "ROLE_SUPER_MANAGER".equals(u.getRole().getName().name())))
                .collect(Collectors.toList());
        if (!users.isEmpty()) {
            users.forEach(u -> u.setDeleted(true));
            userRepository.saveAll(users);
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

    @GetMapping("/recycle-bin/orders")
    public ResponseEntity<List<OrderDto>> getDeletedOrders() {
        return ResponseEntity.ok(orderService.getDeletedOrders());
    }

    @PostMapping("/recycle-bin/orders/{orderId}/restore")
    public ResponseEntity<?> restoreOrder(@PathVariable Long orderId) {
        orderService.restoreOrder(orderId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/recycle-bin/products")
    public ResponseEntity<List<ProductDto>> getDeletedProducts() {
        return ResponseEntity.ok(productService.getDeletedProducts());
    }

    @PostMapping("/recycle-bin/products/{productId}/restore")
    public ResponseEntity<?> restoreProduct(@PathVariable Long productId) {
        productService.restoreProduct(productId);
        return ResponseEntity.ok().build();
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

    @PutMapping("/orders/{id}/status")
    public ResponseEntity<OrderDto> updateOrderStatus(@PathVariable Long id, @RequestParam Order.OrderStatus status,
                                                     @AuthenticationPrincipal UserDetailsImpl userDetails) {
        return ResponseEntity.ok(orderService.updateOrderStatus(id, status, userDetails.getId()));
    }

    @PostMapping("/orders")
    public ResponseEntity<OrderDto> createOrder(@Valid @RequestBody AdminOrderRequest orderRequest) {
        return ResponseEntity.ok(orderService.createAdminOrder(orderRequest));
    }
}
