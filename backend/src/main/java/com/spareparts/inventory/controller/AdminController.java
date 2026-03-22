
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
import java.util.stream.StreamSupport;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity.BodyBuilder;
import com.spareparts.inventory.repository.VoiceTrainingSampleRepository;
import com.spareparts.inventory.entity.VoiceTrainingSample;
import java.util.stream.Collectors;

@CrossOrigin(origins = "${app.cors.allowed-origins}", maxAge = 3600)
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

    @Autowired
    private VoiceTrainingSampleRepository voiceTrainingSampleRepository;

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

    @GetMapping("/ai/voice/samples")
    public ResponseEntity<?> getVoiceSamples(@RequestParam(required = false) String role,
                                             @RequestParam(required = false) String from,
                                             @RequestParam(required = false) String to,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "50") int size,
                                             @RequestParam(required = false) Boolean export) {
        LocalDateTime fromDt = null, toDt = null;
        try {
            if (from != null && !from.isEmpty()) fromDt = LocalDateTime.parse(from);
            if (to != null && !to.isEmpty()) toDt = LocalDateTime.parse(to);
        } catch (DateTimeParseException e) {
            return ResponseEntity.badRequest().body("Invalid date format. Use ISO-8601, e.g., 2026-03-19T00:00:00");
        }
        var pageData = voiceTrainingSampleRepository.findFiltered(role, fromDt, toDt, PageRequest.of(page, size));
        if (Boolean.TRUE.equals(export)) {
            StringBuilder csv = new StringBuilder();
            csv.append("id,createdAt,userId,role,query,productId,productName,price\n");
            for (VoiceTrainingSample s : pageData.getContent()) {
                csv.append(s.getId() == null ? "" : s.getId()).append(",")
                   .append(s.getCreatedAt()).append(",")
                   .append(s.getUserId() == null ? "" : s.getUserId()).append(",")
                   .append(s.getRole() == null ? "" : s.getRole()).append(",")
                   .append(s.getQuery() == null ? "" : s.getQuery().replace(',', ' ')).append(",")
                   .append(s.getProductId() == null ? "" : s.getProductId()).append(",")
                   .append(s.getProductName() == null ? "" : s.getProductName().replace(',', ' ')).append(",")
                   .append(s.getPrice() == null ? "" : s.getPrice()).append("\n");
            }
            BodyBuilder builder = ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=voice_training_samples.csv")
                    .contentType(MediaType.parseMediaType("text/csv"));
            return builder.body(csv.toString());
        }
        return ResponseEntity.ok(pageData);
    }

    @GetMapping("/users")
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findByDeletedFalse());
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<User> getUserById(@PathVariable Long id) {
        return userRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
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

    @DeleteMapping("/recycle-bin/users/{userId}/permanent")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteUserPermanent(@PathVariable Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        if (user.getRole() != null && "ROLE_SUPER_MANAGER".equals(user.getRole().getName().name())) {
            return ResponseEntity.status(403).body("Cannot delete SUPER_MANAGER");
        }
        userRepository.delete(user);
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

    @PutMapping("/users/{userId}/points")
    public ResponseEntity<?> adjustUserPoints(@PathVariable Long userId, @RequestParam Long points, @RequestParam(defaultValue = "SET") String operation) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        if ("ADD".equalsIgnoreCase(operation)) {
            user.setPoints(user.getPoints() + points);
        } else if ("SUBTRACT".equalsIgnoreCase(operation)) {
            user.setPoints(Math.max(0, user.getPoints() - points));
        } else {
            user.setPoints(points);
        }
        
        userRepository.save(user);
        return ResponseEntity.ok(Map.of("userId", userId, "newPoints", user.getPoints()));
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

    @PutMapping("/users/{userId}/address")
    public ResponseEntity<?> updateUserAddress(@PathVariable Long userId, @RequestBody Map<String, String> body) {
        String address = body.getOrDefault("address", "");
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setAddress(address);
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/users/{userId}/location")
    public ResponseEntity<?> updateUserLocation(@PathVariable Long userId, @RequestBody Map<String, Double> body) {
        Double lat = body.get("latitude");
        Double lon = body.get("longitude");
        if (lat == null || lon == null) {
            return ResponseEntity.badRequest().body("Latitude and longitude are required");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setLatitude(lat);
        user.setLongitude(lon);
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/products/{productId}/offer")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> setProductOffer(
            @PathVariable Long productId,
            @RequestParam String offerType,
            @RequestParam(defaultValue = "false") boolean notifyWhatsApp,
            @RequestParam(defaultValue = "true") boolean notifyInApp,
            @RequestParam(required = false) Integer minQty) {
        productService.setProductOffer(productId, offerType, notifyWhatsApp, notifyInApp, minQty);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/users/update-location")
    public ResponseEntity<?> updateUserLocationBody(@RequestBody Map<String, Object> body) {
        Object idObj = body.get("userId");
        Double lat = body.get("latitude") instanceof Number ? ((Number) body.get("latitude")).doubleValue() : null;
        Double lon = body.get("longitude") instanceof Number ? ((Number) body.get("longitude")).doubleValue() : null;
        if (!(idObj instanceof Number) || lat == null || lon == null) {
            return ResponseEntity.badRequest().body("userId, latitude and longitude are required");
        }
        Long userId = ((Number) idObj).longValue();
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setLatitude(lat);
        user.setLongitude(lon);
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

    @DeleteMapping("/recycle-bin/orders/{orderId}/permanent")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteOrderPermanent(@PathVariable Long orderId) {
        orderService.deleteOrderPermanent(orderId);
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

    @DeleteMapping("/recycle-bin/products/{productId}/permanent")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteProductPermanent(@PathVariable Long productId) {
        productService.deleteProductPermanent(productId);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/orders/{orderId}")
    public ResponseEntity<?> deleteOrder(@PathVariable Long orderId) {
        orderService.deleteOrder(orderId);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/orders/{orderId}/items")
    @PreAuthorize("hasRole('SUPER_MANAGER') or hasRole('ADMIN')")
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
