
package com.spareparts.inventory.controller;

import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
import java.util.HashMap;

@RestController
@RequestMapping("/api/test")
@CrossOrigin(origins = "*")
public class TestController {
    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProductRepository productRepository;

    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> res = new HashMap<>();
        res.put("status", "UP");
        res.put("message", "Inventory System is running");
        return res;
    }

    @GetMapping("/stats")
    public Map<String, Object> stats() {
        Map<String, Object> res = new HashMap<>();
        res.put("totalUsers", userRepository.count());
        res.put("activeUsers", userRepository.findByDeletedFalse().size());
        res.put("totalProducts", productRepository.count());
        res.put("activeProducts", productRepository.findByDeletedFalse().size());
        return res;
    }
}
