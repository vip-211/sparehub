package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.security.UserDetailsImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.HashMap;
import java.util.List;

@CrossOrigin(origins = "${app.cors.allowed-origins}", maxAge = 3600)
@RestController
@RequestMapping("/api/users")
public class UserController {
    @Autowired
    private UserRepository userRepository;

    @GetMapping("/profile")
    public ResponseEntity<?> getProfile(@AuthenticationPrincipal UserDetailsImpl userDetails) {
        User user = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("User not found"));

        Map<String, Object> response = new HashMap<>();
        response.put("id", user.getId());
        response.put("email", user.getEmail());
        response.put("name", user.getName());
        response.put("phone", user.getPhone());
        response.put("address", user.getAddress());
        response.put("status", user.getStatus().name());
        response.put("latitude", user.getLatitude());
        response.put("longitude", user.getLongitude());
        response.put("points", user.getPoints());
        
        String roleName = "ROLE_MECHANIC";
        if (user.getRole() != null && user.getRole().getName() != null) {
            roleName = user.getRole().getName().name();
        }
        response.put("roles", List.of(roleName));
        
        return ResponseEntity.ok(response);
    }

    @PutMapping("/profile")
    public ResponseEntity<?> updateProfile(@AuthenticationPrincipal UserDetailsImpl userDetails,
                                          @RequestBody Map<String, String> body) {
        User user = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (body.containsKey("name")) {
            user.setName(body.get("name"));
        }
        if (body.containsKey("phone")) {
            user.setPhone(body.get("phone"));
        }
        if (body.containsKey("address")) {
            user.setAddress(body.get("address"));
        }

        User savedUser = userRepository.save(user);
        
        Map<String, Object> response = new HashMap<>();
        response.put("id", savedUser.getId());
        response.put("email", savedUser.getEmail());
        response.put("name", savedUser.getName());
        response.put("phone", savedUser.getPhone());
        response.put("address", savedUser.getAddress());
        response.put("status", savedUser.getStatus().name());
        response.put("latitude", savedUser.getLatitude());
        response.put("longitude", savedUser.getLongitude());
        response.put("points", savedUser.getPoints());
        
        String roleName = "ROLE_MECHANIC";
        if (savedUser.getRole() != null && savedUser.getRole().getName() != null) {
            roleName = savedUser.getRole().getName().name();
        }
        response.put("roles", List.of(roleName));
        
        return ResponseEntity.ok(response);
    }

    @PutMapping("/address")
    public ResponseEntity<?> updateAddress(@AuthenticationPrincipal UserDetailsImpl userDetails,
                                          @RequestBody Map<String, String> body) {
        User user = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setAddress(body.getOrDefault("address", ""));
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/location")
    public ResponseEntity<?> updateLocation(@AuthenticationPrincipal UserDetailsImpl userDetails,
                                           @RequestBody Map<String, Double> body) {
        User user = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setLatitude(body.get("latitude"));
        user.setLongitude(body.get("longitude"));
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }
}
