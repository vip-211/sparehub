
package com.spareparts.inventory.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
import java.util.HashMap;

@RestController
@RequestMapping("/api/test")
public class TestController {

    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> res = new HashMap<>();
        res.put("status", "UP");
        res.put("message", "Inventory System is running");
        return res;
    }
}
