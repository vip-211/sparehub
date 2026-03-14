package com.spareparts.inventory.controller;

import com.spareparts.inventory.service.AIService;
import com.spareparts.inventory.service.OrderService;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.dto.OrderRequest;
import com.spareparts.inventory.dto.OrderItemDto;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.security.UserDetailsImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;
import java.util.List;
import java.util.ArrayList;

@RestController
@RequestMapping("/api/ai")
public class AIController {

    @Autowired
    private AIService aiService;
    @Autowired
    private OrderService orderService;
    @Autowired
    private ProductRepository productRepository;

    @PostMapping("/chat")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, String>> chat(@RequestBody Map<String, String> request,
                                                    @RequestHeader(value = "X-AI-Provider", required = false) String provider) {
        String prompt = request.get("prompt");
        String response = aiService.askAI(prompt, provider);
        return ResponseEntity.ok(Map.of("response", response));
    }

    @PostMapping("/search/photo")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, String>> searchByPhoto(@RequestParam("image") MultipartFile image,
                                                             @RequestHeader(value = "X-AI-Provider", required = false) String provider) {
        String response = aiService.searchByPhoto(image, provider);
        return ResponseEntity.ok(Map.of("response", response));
    }

    @PostMapping("/search/voice")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, String>> searchByVoice(@RequestParam("audio") MultipartFile audio,
                                                             @RequestHeader(value = "X-AI-Provider", required = false) String provider) {
        String response = aiService.searchByVoice(audio, provider);
        return ResponseEntity.ok(Map.of("response", response));
    }

    @PostMapping("/feedback")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<?> feedback(@RequestBody Map<String, Object> request) {
        // In a real production app, we would save this to a database table 'ai_feedback'
        // For now, we log it to console/server logs as requested for "training"
        System.out.println("AI Feedback Received: " + request);
        return ResponseEntity.ok(Map.of("message", "Feedback recorded"));
    }

    @PostMapping("/train")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<?> train(@RequestBody Map<String, Object> request) {
        // Similar to feedback, record corrections for manual model fine-tuning
        System.out.println("AI Training Correction Received: " + request);
        return ResponseEntity.ok(Map.of("message", "Correction recorded for training"));
    }

    @PostMapping("/order")
    @PreAuthorize("hasRole('RETAILER') or hasRole('MECHANIC') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<Map<String, Object>> order(@RequestBody Map<String, Object> request, Authentication authentication) {
        Object pidObj = request.get("productId");
        Object qtyObj = request.getOrDefault("quantity", 1);
        if (pidObj == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "productId is required"));
        }
        Long productId = (pidObj instanceof Number) ? ((Number) pidObj).longValue() : Long.parseLong(pidObj.toString());
        int quantity = (qtyObj instanceof Number) ? ((Number) qtyObj).intValue() : Integer.parseInt(qtyObj.toString());
        if (quantity <= 0) quantity = 1;

        Product product = productRepository.findById(productId).orElse(null);
        if (product == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Product not found"));
        }

        OrderItemDto item = new OrderItemDto();
        item.setProductId(product.getId());
        item.setProductName(product.getName());
        item.setQuantity(quantity);

        OrderRequest orderRequest = new OrderRequest();
        orderRequest.setSellerId(product.getWholesaler().getId());
        List<OrderItemDto> items = new ArrayList<>();
        items.add(item);
        orderRequest.setItems(items);

        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        var dto = orderService.createOrder(orderRequest, userDetails.getId());
        return ResponseEntity.ok(Map.of("orderId", dto.getId(), "status", dto.getStatus().toString(), "total", dto.getTotalAmount()));
    }
}
