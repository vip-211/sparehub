
package com.spareparts.inventory.controller;

import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
import java.util.HashMap;
import java.time.Instant;

@RestController
@RequestMapping(value = "/api", produces = "application/json")
@CrossOrigin(origins = "*")
public class TestController {
    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProductRepository productRepository;

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> healthCheck() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "OK");
        response.put("message", "Your API is running");
        response.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/test/stats")
    public Map<String, Object> stats() {
        Map<String, Object> res = new HashMap<>();
        res.put("totalUsers", userRepository.count());
        res.put("activeUsers", userRepository.findByDeletedFalse().size());
        res.put("totalProducts", productRepository.count());
        res.put("activeProducts", productRepository.findByDeletedFalse().size());
        return res;
    }
}
