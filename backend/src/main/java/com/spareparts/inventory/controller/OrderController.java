
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.*;
import com.spareparts.inventory.entity.Order;
import com.spareparts.inventory.security.UserDetailsImpl;
import com.spareparts.inventory.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@CrossOrigin(origins = "${app.cors.allowed-origins}", maxAge = 3600)
@RestController
@RequestMapping("/api/orders")
public class OrderController {
    @Autowired
    private OrderService orderService;

    @PostMapping
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('RETAILER') or hasRole('MECHANIC')")
    public ResponseEntity<OrderDto> createOrder(@Valid @RequestBody OrderRequest orderRequest,
                                               @AuthenticationPrincipal UserDetailsImpl userDetails) {
        return ResponseEntity.ok(orderService.createOrder(orderRequest, userDetails.getId()));
    }

    @PostMapping("/custom-request")
    @PreAuthorize("hasRole('RETAILER') or hasRole('MECHANIC') or hasRole('WHOLESALER')")
    public ResponseEntity<CustomOrderRequestDto> createCustomOrderRequest(@RequestBody Map<String, String> payload,
                                                                         @AuthenticationPrincipal UserDetailsImpl userDetails) {
        String text = payload.get("text");
        String photoPath = payload.get("photoPath");
        return ResponseEntity.ok(orderService.createCustomOrderRequest(text, photoPath, userDetails.getId()));
    }

    @GetMapping("/custom-requests")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<List<CustomOrderRequestDto>> getAllCustomOrderRequests() {
        return ResponseEntity.ok(orderService.getAllCustomOrderRequests());
    }

    @PutMapping("/custom-requests/{id}/status")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<CustomOrderRequestDto> updateCustomOrderRequestStatus(@PathVariable Long id,
                                                                               @RequestParam String status,
                                                                               @RequestParam(required = false) Long staffId) {
        return ResponseEntity.ok(orderService.updateCustomOrderRequestStatus(id, status, staffId));
    }

    @GetMapping("/my-orders")
    public ResponseEntity<List<OrderDto>> getMyOrders(Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(orderService.getCustomerOrders(userDetails.getId()));
    }

    @GetMapping("/seller-orders")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('RETAILER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<List<OrderDto>> getSellerOrders(Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(orderService.getSellerOrders(userDetails.getId()));
    }

    @GetMapping("/staff-orders")
    @PreAuthorize("hasRole('STAFF') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<List<OrderDto>> getStaffOrders(Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(orderService.getStaffOrders(userDetails.getId()));
    }

    @PutMapping("/{orderId}/status")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('RETAILER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<OrderDto> updateOrderStatus(@PathVariable Long orderId, @RequestParam Order.OrderStatus status, Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(orderService.updateOrderStatus(orderId, status, userDetails.getId()));
    }

    @PutMapping("/{orderId}/cancel")
    @PreAuthorize("hasRole('RETAILER') or hasRole('MECHANIC')")
    public ResponseEntity<OrderDto> cancelOrder(@PathVariable Long orderId, Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(orderService.cancelOrder(orderId, userDetails.getId()));
    }
}
