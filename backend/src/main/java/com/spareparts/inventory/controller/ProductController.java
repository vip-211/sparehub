package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.PaginatedResponse;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.dto.SuggestionDto;
import com.spareparts.inventory.dto.ChatResponse;
import com.spareparts.inventory.repository.SystemSettingRepository;
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
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.CacheEvict;

import java.util.List;
import java.util.ArrayList;
import java.util.Deque;
import java.util.ArrayDeque;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import java.util.Objects;
import java.util.Collections;
import java.util.stream.Stream;

@RestController
@RequestMapping("/api/products")
@CrossOrigin(origins = "*")
public class ProductController {
    @Autowired
    private ProductService productService;

    @Autowired
    private AIService aiService;

    @Autowired
    private AgentService agentService;
    
    @Autowired(required = false)
    private SystemSettingRepository systemSettingRepository;
    
    private static final ConcurrentHashMap<String, Deque<Long>> RATE = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, CacheEntry> CACHE = new ConcurrentHashMap<>();
    private static final int MAX_CACHE_SIZE = 1000;
    
    private static record CacheEntry(Object body, long expiryMs) {}

    @Scheduled(fixedRate = 60000)
    public void cleanCache() {
        long now = System.currentTimeMillis();
        CACHE.entrySet().removeIf(e -> now > e.getValue().expiryMs());
        if (CACHE.size() > MAX_CACHE_SIZE) {
            // Very simple LRU-ish cleanup: if still too big, clear half
            List<String> keys = new ArrayList<>(CACHE.keySet());
            for (int i = 0; i < keys.size() / 2; i++) {
                CACHE.remove(keys.get(i));
            }
        }
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
    @CacheEvict(cacheNames = {"home_featured_products"}, allEntries = true)
    public ResponseEntity<ProductDto> addProduct(@Valid @RequestBody ProductDto productDto, Authentication authentication) {
        if (productDto == null) return ResponseEntity.badRequest().build();
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_SUPER_MANAGER"));
        
        // Only admin/super manager can fix minimum quantity
        if (!isAdmin) {
            productDto.setMinOrderQty(1);
        }
        
        return ResponseEntity.ok(productService.addProduct(productDto, userDetails.getId()));
    }

    @PostMapping("/bulk")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_featured_products"}, allEntries = true)
    public ResponseEntity<?> addProductsBulk(@RequestBody List<ProductDto> productDtos, Authentication authentication) {
        if (productDtos == null || productDtos.isEmpty()) {
            return ResponseEntity.badRequest().body("Products list cannot be empty");
        }
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_SUPER_MANAGER"));

        if (!isAdmin) {
            productDtos.forEach(dto -> dto.setMinOrderQty(1));
        }

        productService.addProductsBulk(productDtos, userDetails.getId());
        return ResponseEntity.ok().build();
    }

    @GetMapping("/suggest")
    public ResponseEntity<List<SuggestionDto>> suggest(@RequestParam String query) {
        if (query == null || query.trim().isEmpty()) {
            return ResponseEntity.ok(Collections.emptyList());
        }
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
        if (query == null || query.trim().isEmpty()) {
            return ResponseEntity.ok(Collections.emptyList());
        }
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
                    .map(o -> o[1] + " (Sold: " + o[2] + ")")
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
        if (query == null || query.trim().isEmpty()) {
            ChatResponse empty = new ChatResponse();
            empty.setMessage("What can I help you find?");
            return ResponseEntity.ok(empty);
        }
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
        if (query == null || query.trim().isEmpty()) {
            return ResponseEntity.ok(new PaginatedResponse<>(Collections.emptyList(), page, size, 0, 0, true));
        }
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
        if (type == null || type.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(null);
        }
        try {
            return ResponseEntity.ok(productService.getProductsByOfferType(type, page, size, sortBy, direction));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(null);
        }
    }

    @GetMapping("/featured")
    @Cacheable(cacheNames = "home_featured_products")
    public ResponseEntity<List<ProductDto>> getFeaturedProducts() {
        return ResponseEntity.ok(productService.getFeaturedProducts());
    }

    @GetMapping("/{id}")
    public ResponseEntity<ProductDto> getProductById(@PathVariable Long id) {
        ProductDto productDto = productService.getProductById(id);
        if (productDto != null) {
            return ResponseEntity.ok(productDto);
        } else {
            return ResponseEntity.notFound().build();
        }
    }

    @PostMapping("/featured")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_featured_products"}, allEntries = true)
    public ResponseEntity<?> updateFeaturedStatus(@RequestBody java.util.Map<String, Object> body) {
        if (body == null || !body.containsKey("ids") || !body.containsKey("isFeatured")) {
            return ResponseEntity.badRequest().body("Missing required fields: ids, isFeatured");
        }
        @SuppressWarnings("unchecked")
        List<Integer> idsInt = (List<Integer>) body.get("ids");
        if (idsInt == null || idsInt.isEmpty()) return ResponseEntity.badRequest().body("ids cannot be null or empty");
        List<Long> ids = idsInt.stream().map(Integer::longValue).collect(Collectors.toList());
        boolean isFeatured = (boolean) body.get("isFeatured");
        productService.updateFeaturedStatus(ids, isFeatured);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_featured_products"}, allEntries = true)
    public ResponseEntity<ProductDto> updateProduct(@PathVariable Long id, @Valid @RequestBody ProductDto productDto, Authentication authentication) {
        if (productDto == null) return ResponseEntity.badRequest().build();
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_SUPER_MANAGER"));

        if (!isAdmin) {
            // Wholesalers cannot change the minimum order quantity
            productDto.setMinOrderQty(null); // ProductService will keep existing or default if null is handled
        }
        return ResponseEntity.ok(productService.updateProduct(id, productDto));
    }

    @DeleteMapping("/empty-recycle-bin")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_featured_products"}, allEntries = true)
    public ResponseEntity<?> emptyRecycleBin() {
        productService.emptyRecycleBin();
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_featured_products"}, allEntries = true)
    public ResponseEntity<?> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/delete-bulk")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_featured_products"}, allEntries = true)
    public ResponseEntity<?> deleteProductsBulk(@RequestBody List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return ResponseEntity.badRequest().body("Ids list cannot be empty");
        }
        productService.deleteProductsBulk(ids);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/trending")
    public ResponseEntity<List<ProductDto>> getTrendingProducts() {
        return ResponseEntity.ok(productService.getTrendingProducts());
    }

    @GetMapping("/{id}/aliases")
    public ResponseEntity<List<java.util.Map<String, Object>>> getAliases(@PathVariable Long id) {
        return ResponseEntity.ok(productService.getAliases(id));
    }

    @PostMapping("/{id}/aliases")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> addAlias(@PathVariable Long id, @RequestBody java.util.Map<String, String> body) {
        if (body == null || !body.containsKey("alias")) {
            return ResponseEntity.badRequest().body("Alias is required");
        }
        productService.addAlias(id, body.get("alias"), body.get("pronunciation"));
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/aliases/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteAlias(@PathVariable Long id) {
        productService.deleteAlias(id);
        return ResponseEntity.ok().build();
    }
}
