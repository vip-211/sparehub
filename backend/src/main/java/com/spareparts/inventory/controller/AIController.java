package com.spareparts.inventory.controller;

import com.spareparts.inventory.service.AIService;
import com.spareparts.inventory.service.OrderService;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.VoiceTrainingSampleRepository;
import com.spareparts.inventory.entity.VoiceTrainingSample;
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

import com.spareparts.inventory.repository.AITrainingCorrectionRepository;
import com.spareparts.inventory.entity.AITrainingCorrection;

import com.spareparts.inventory.service.AgentService;
import com.spareparts.inventory.service.PredictionService;
@RestController
@RequestMapping(value = "/api/ai", produces = "application/json")
public class AIController {
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(AIController.class);

    @Autowired
    private AIService aiService;
    @Autowired
    private AgentService agentService;
    @Autowired
    private PredictionService predictionService;
    @Autowired
    private OrderService orderService;
    @Autowired
    private ProductRepository productRepository;
    @Autowired
    private VoiceTrainingSampleRepository voiceTrainingSampleRepository;
    @Autowired
    private AITrainingCorrectionRepository trainingCorrectionRepository;

    @PostMapping("/chat")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, String>> chat(@RequestBody Map<String, String> request,
                                                    @RequestHeader(value = "X-AI-Provider", required = false) String provider,
                                                    Authentication authentication) {
        String prompt = request.get("prompt");
        Long userId = null;
        if (authentication != null && authentication.getPrincipal() instanceof UserDetailsImpl) {
            userId = ((UserDetailsImpl) authentication.getPrincipal()).getId();
        }
        String response = agentService.processQuery(prompt, provider, userId);
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
        log.info("AI Feedback Received: {}", request);
        return ResponseEntity.ok(Map.of("message", "Feedback recorded"));
    }

    @GetMapping("/stock/predict")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> predictStock() {
        List<String> suggestions = predictionService.getRestockSuggestions();
        return ResponseEntity.ok(suggestions);
    }

    @PostMapping("/train")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> train(@RequestBody Map<String, Object> request) {
        log.info("AI Training Correction Received: {}", request);
        try {
            String prompt = (String) request.get("prompt");
            String originalResponse = (String) request.get("originalResponse");
            String correctedResponse = (String) request.get("correctedResponse");

            if (prompt != null && correctedResponse != null) {
                AITrainingCorrection correction = new AITrainingCorrection();
                correction.setPrompt(prompt);
                correction.setOriginalResponse(originalResponse);
                correction.setCorrectedResponse(correctedResponse);
                trainingCorrectionRepository.save(correction);
                return ResponseEntity.ok(Map.of("message", "Correction recorded and applied for future queries"));
            }
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid training data"));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/voice/train")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<?> trainVoice(@RequestBody Map<String, Object> request,
                                        Authentication authentication) {
        try {
            String query = request.get("query") != null ? request.get("query").toString() : null;
            Long productId = null;
            if (request.get("productId") instanceof Number) {
                productId = ((Number) request.get("productId")).longValue();
            } else if (request.get("productId") != null) {
                productId = Long.parseLong(request.get("productId").toString());
            }
            String productName = request.get("productName") != null ? request.get("productName").toString() : null;
            Double price = null;
            if (request.get("price") instanceof Number) {
                price = ((Number) request.get("price")).doubleValue();
            } else if (request.get("price") != null) {
                price = Double.parseDouble(request.get("price").toString());
            }

            VoiceTrainingSample sample = new VoiceTrainingSample();
            sample.setQuery(query);
            sample.setProductId(productId);
            sample.setProductName(productName);
            sample.setPrice(price);
            if (authentication != null && authentication.getPrincipal() instanceof UserDetailsImpl u) {
                sample.setUserId(u.getId());
                sample.setRole(u.getAuthorities().stream().findFirst().map(a -> a.getAuthority()).orElse(null));
            }
            voiceTrainingSampleRepository.save(sample);
            return ResponseEntity.ok(Map.of("message", "Recorded"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
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
