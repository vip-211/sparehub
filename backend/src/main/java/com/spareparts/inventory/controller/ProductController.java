
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.PaginatedResponse;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.dto.SuggestionDto;
import com.spareparts.inventory.dto.ChatResponse;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.security.UserDetailsImpl;
import com.spareparts.inventory.service.ProductService;
import com.spareparts.inventory.service.AIService;
import com.spareparts.inventory.service.AgentService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.ArrayList;
import java.util.Deque;
import java.util.ArrayDeque;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import java.util.Objects;
import java.util.Collections;

@RestController
@RequestMapping("/api/products")
public class ProductController {
    @Autowired
    private ProductService productService;

    @Autowired
    private AIService aiService;

    @Autowired
    private AgentService agentService;
    
    @Autowired(required = false)
    private com.spareparts.inventory.repository.SystemSettingRepository systemSettingRepository;
    
    private static final ConcurrentHashMap<String, Deque<Long>> RATE = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, CacheEntry> CACHE = new ConcurrentHashMap<>();
    
    private static record CacheEntry(Object body, long expiryMs) {}

    @Scheduled(fixedRate = 60000)
    public void cleanCache() {
        long now = System.currentTimeMillis();
        CACHE.entrySet().removeIf(e -> now > e.getValue().expiryMs());
        RATE.entrySet().removeIf(e -> {
            synchronized (e.getValue()) {
                while (!e.getValue().isEmpty() && now - e.getValue().peekFirst() > getRateWindowMs()) {
                    e.getValue().pollFirst();
                }
                return e.getValue().isEmpty();
            }
        });
    }
    
    private boolean allowRequest(String key) {
        long now = System.currentTimeMillis();
        Deque<Long> dq = RATE.computeIfAbsent(key, k -> new ArrayDeque<>());
        int rateLimit = getRateLimit();
        long windowMs = getRateWindowMs();
        synchronized (dq) {
            while (!dq.isEmpty() && now - dq.peekFirst() > windowMs) {
                dq.pollFirst();
            }
            if (dq.size() >= rateLimit) return false;
            dq.addLast(now);
            return true;
        }
    }
    
    private int getRateLimit() {
        try {
            if (systemSettingRepository != null) {
                String v = systemSettingRepository.getSettingValue("PRODUCT_SEARCH_RATE_LIMIT", "20");
                return Integer.parseInt(v);
            }
        } catch (Exception ignored) {}
        return 20;
    }
    
    private long getRateWindowMs() {
        try {
            if (systemSettingRepository != null) {
                String v = systemSettingRepository.getSettingValue("PRODUCT_SEARCH_RATE_WINDOW_MS", "30000");
                return Long.parseLong(v);
            }
        } catch (Exception ignored) {}
        return 30_000L;
    }
    
    private long getCacheTtlMs() {
        try {
            if (systemSettingRepository != null) {
                String v = systemSettingRepository.getSettingValue("PRODUCT_SEARCH_CACHE_TTL_MS", "15000");
                return Long.parseLong(v);
            }
        } catch (Exception ignored) {}
        return 15_000L;
    }

    @PostMapping
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<ProductDto> addProduct(@Valid @RequestBody ProductDto productDto, Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(productService.addProduct(productDto, userDetails.getId()));
    }

    @PostMapping("/bulk")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> addProductsBulk(@RequestBody List<ProductDto> productDtos, Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        productService.addProductsBulk(productDtos, userDetails.getId());
        return ResponseEntity.ok().build();
    }

    @GetMapping("/suggest")
    public ResponseEntity<List<SuggestionDto>> suggest(@RequestParam String query) {
        try {
            // Fix: ensure we provide all 5 arguments to searchProducts, sort by stock to show available items first
            PaginatedResponse<ProductDto> response = productService.searchProducts(query, 0, 5, "stock", "desc");
            if (response == null || response.getContent() == null) {
                return ResponseEntity.ok(Collections.emptyList());
            }
            List<SuggestionDto> suggestions = response.getContent()
                    .stream()
                    .map(p -> {
                        SuggestionDto dto = new SuggestionDto();
                        dto.setName(p.getName());
                        dto.setPartNumber(p.getPartNumber());
                        dto.setPrice(p.getSellingPrice());
                        dto.setStock(p.getStock());
                        return dto;
                    })
                    .collect(Collectors.toList());
            return ResponseEntity.ok(suggestions);
        } catch (Exception e) {
            return ResponseEntity.ok(Collections.emptyList());
        }
    }

    @GetMapping("/suggest/context")
    public ResponseEntity<List<String>> suggestWithContext(
            @RequestParam String query,
            Authentication authentication) {
        try {
            UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
            String history = agentService.getChatHistoryText(userDetails.getId());
            
            PaginatedResponse<ProductDto> products = productService.searchProducts(query, 0, 5, "id", "desc");
            if (products == null || products.getContent() == null || products.getContent().isEmpty()) {
                return ResponseEntity.ok(Collections.emptyList());
            }

            String productList = products.getContent().stream()
                    .map(p -> p.getName() + " (" + p.getPartNumber() + ")")
                    .collect(Collectors.joining(", "));

            String prompt = String.format(
                "Based on the user's recent chat history and current search query, identify the most relevant spare parts from the provided list.\n\n" +
                "User Search Query: %s\n" +
                "Recent Chat History:\n%s\n\n" +
                "Available Products: %s\n\n" +
                "Instructions:\n" +
                "- Return ONLY the top 3 product names, comma-separated.\n" +
                "- Prioritize parts that match the context of previous messages.\n" +
                "- If no strong context exists, return the top results from the list.",
                query, history, productList
            );

            String aiResponse = aiService.askAI(prompt, "gemini", userDetails.getId());
            List<String> results = List.of(aiResponse.split(",\\s*"));
            return ResponseEntity.ok(results);
        } catch (Exception e) {
            return ResponseEntity.ok(Collections.emptyList());
        }
    }

    @GetMapping("/recommendations")
    public ResponseEntity<String> getRecommendations(Authentication authentication) {
        try {
            UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
            List<Object[]> topSelling = productService.getTopSellingProducts();
            
            if (topSelling.isEmpty()) {
                return ResponseEntity.ok("I don't have enough sales data to make recommendations yet.");
            }

            String bestSellers = topSelling.stream()
                    .limit(5)
                    .map(o -> o[0] + " (Sold: " + o[1] + ")")
                    .collect(Collectors.joining("\n"));

            String prompt = String.format(
                "Analyze these top-selling spare parts and provide strategic stock recommendations for the shop owner.\n\n" +
                "Top Sellers:\n%s\n\n" +
                "Instructions:\n" +
                "- Identify high-demand items.\n" +
                "- Suggest what to restock or promote.\n" +
                "- Keep it professional and helpful.\n" +
                "- Use bullet points.",
                bestSellers
            );

            return ResponseEntity.ok(aiService.askAI(prompt, "gemini", userDetails.getId()));
        } catch (Exception e) {
            return ResponseEntity.ok("Failed to fetch recommendations.");
        }
    }

    @GetMapping("/chat-suggest")
    public ResponseEntity<ChatResponse> chatSuggest(@RequestParam String query) {
        try {
            PaginatedResponse<ProductDto> response = productService.searchProducts(query, 0, 3, "stock", "desc");
            ChatResponse res = new ChatResponse();
            
            if (response == null || response.getContent() == null || response.getContent().isEmpty()) {
                res.setMessage("I couldn't find any parts matching '" + query + "'.");
                res.setQuickReplies(List.of("Search again", "Need assistance", "Show all parts"));
            } else {
                String parts = response.getContent().stream()
                        .map(p -> "• " + p.getName() + " (₹" + p.getSellingPrice() + ")")
                        .collect(Collectors.joining("\n"));
                res.setMessage("🔍 I found some matching parts for you:\n\n" + parts);
                res.setQuickReplies(List.of("Create Invoice", "Check Stock", "Show Alternatives"));
            }
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            ChatResponse err = new ChatResponse();
            err.setMessage("Error fetching suggestions.");
            return ResponseEntity.ok(err);
        }
    }

    @GetMapping("/wholesaler")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<PaginatedResponse<ProductDto>> getWholesalerProducts(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction,
            Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(productService.getWholesalerProducts(userDetails.getId(), page, size, sortBy, direction));
    }

    @GetMapping
    public ResponseEntity<PaginatedResponse<ProductDto>> getAllProducts(
            @RequestParam(required = false) Long categoryId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction) {
        if (categoryId != null) {
            return ResponseEntity.ok(productService.getProductsByCategory(categoryId, page, size, sortBy, direction));
        }
        return ResponseEntity.ok(productService.getAllProducts(page, size, sortBy, direction));
    }

    @GetMapping("/search")
    public ResponseEntity<PaginatedResponse<ProductDto>> searchProducts(
            @RequestParam String query,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction) {
        String key = String.join("|", "search", query.trim().toLowerCase(), String.valueOf(page), String.valueOf(size), sortBy, direction);
        CacheEntry cached = CACHE.get(key);
        long now = System.currentTimeMillis();
        if (cached != null && now < cached.expiryMs()) {
            @SuppressWarnings("unchecked")
            PaginatedResponse<ProductDto> body = (PaginatedResponse<ProductDto>) cached.body();
            return ResponseEntity.ok(body);
        }
        String clientKey = key;
        if (!allowRequest(clientKey)) {
            return ResponseEntity.status(429).body(null);
        }
        PaginatedResponse<ProductDto> body = productService.searchProducts(query, page, size, sortBy, direction);
        CACHE.put(key, new CacheEntry(body, now + getCacheTtlMs()));
        return ResponseEntity.ok(body);
    }

    @GetMapping("/offers")
    public ResponseEntity<PaginatedResponse<ProductDto>> getProductsByOfferType(
            @RequestParam String type,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction) {
        return ResponseEntity.ok(productService.getProductsByOfferType(type, page, size, sortBy, direction));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<ProductDto> updateProduct(@PathVariable Long id, @Valid @RequestBody ProductDto productDto, Authentication authentication) {
        return ResponseEntity.ok(productService.updateProduct(id, productDto));
    }

    @DeleteMapping("/empty-recycle-bin")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> emptyRecycleBin() {
        productService.emptyRecycleBin();
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/delete-bulk")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteProductsBulk(@RequestBody List<Long> ids) {
        productService.deleteProductsBulk(ids);
        return ResponseEntity.ok().build();
    }
}
