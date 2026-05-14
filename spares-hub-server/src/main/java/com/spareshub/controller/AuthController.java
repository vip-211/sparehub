package com.spareshub.controller;

import com.spareshub.entity.User;
import com.spareshub.repo.UserRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

@RestController
@RequestMapping("/auth")
public class AuthController {
    private final UserRepo userRepo;
    public AuthController(UserRepo userRepo) { this.userRepo = userRepo; }
    private static final Map<String, String> OTP = new HashMap<>();

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, Object> body) {
        String inputIdentifier = String.valueOf(body.get("identifier"));
        if (inputIdentifier == null || inputIdentifier.equals("null")) {
            inputIdentifier = String.valueOf(body.get("email"));
        }
        final String finalIdentifier = inputIdentifier;
        final String password = String.valueOf(body.get("password"));
        
        return userRepo.findAll().stream()
                .filter(u -> (finalIdentifier.equals(u.getEmail()) || finalIdentifier.equals(u.getPhone())) && password.equals(u.getPassword()))
                .findFirst()
                .map(u -> ResponseEntity.ok(Map.of(
                        "id", u.getId(),
                        "email", u.getEmail(),
                        "name", u.getName(),
                        "roles", List.of(u.getRole())
                )))
                .orElse(ResponseEntity.status(401).body(Map.of("error", "invalid")));
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, Object> body) {
        String email = String.valueOf(body.get("email"));
        if (userRepo.findByEmail(email).isPresent()) return ResponseEntity.badRequest().body(Map.of("error", "exists"));
        User u = new User();
        u.setName(String.valueOf(body.get("name")));
        u.setEmail(email);
        u.setPassword(String.valueOf(body.get("password")));
        u.setRole(String.valueOf(body.get("role")));
        u.setPhone(String.valueOf(body.get("phone")));
        u.setAddress(String.valueOf(body.get("address")));
        if (body.get("latitude") != null) u.setLatitude(Double.parseDouble(String.valueOf(body.get("latitude"))));
        if (body.get("longitude") != null) u.setLongitude(Double.parseDouble(String.valueOf(body.get("longitude"))));
        if ("ROLE_ADMIN".equals(u.getRole()) || "ROLE_STAFF".equals(u.getRole()) || "ROLE_SUPER_MANAGER".equals(u.getRole())) u.setStatus("ACTIVE"); else u.setStatus("PENDING");
        userRepo.save(u);
        return ResponseEntity.ok(Map.of("status", "OK"));
    }

    @PostMapping("/send-otp")
    public ResponseEntity<?> sendOtp(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(Map.of("status", "OK"));
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<?> verifyOtp(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(Map.of("status", "OK"));
    }

    @PostMapping("/google")
    public ResponseEntity<?> google(@RequestBody Map<String, Object> body) {
        String email = String.valueOf(body.get("email"));
        String name = String.valueOf(body.get("name"));
        return userRepo.findByEmail(email)
                .map(u -> ResponseEntity.ok(Map.of(
                        "id", u.getId(),
                        "email", u.getEmail(),
                        "name", u.getName(),
                        "roles", List.of(u.getRole())
                )))
                .orElseGet(() -> {
                    User u = new User();
                    u.setEmail(email);
                    u.setName(name);
                    u.setPassword("sso_google_password");
                    u.setRole("ROLE_RETAILER");
                    u.setStatus("ACTIVE");
                    userRepo.save(u);
                    return ResponseEntity.ok(Map.of(
                            "id", u.getId(),
                            "email", u.getEmail(),
                            "name", u.getName(),
                            "roles", List.of(u.getRole())
                    ));
                });
    }

    @PostMapping("/password/forgot")
    public ResponseEntity<?> forgot(@RequestBody Map<String, Object> body) {
        String email = String.valueOf(body.get("email"));
        return userRepo.findByEmail(email).map(u -> {
            String otp = String.valueOf(100000 + new Random().nextInt(900000));
            OTP.put(email, otp);
            return ResponseEntity.ok(Map.of("status", "OK"));
        }).orElse(ResponseEntity.status(404).body(Map.of("error", "not_found")));
    }

    @PostMapping("/password/reset")
    public ResponseEntity<?> reset(@RequestBody Map<String, Object> body) {
        String email = String.valueOf(body.get("email"));
        String otp = String.valueOf(body.get("otp"));
        String newPassword = String.valueOf(body.get("newPassword"));
        String cached = OTP.get(email);
        if (cached != null && cached.equals(otp)) {
            return userRepo.findByEmail(email).map(u -> {
                u.setPassword(newPassword);
                userRepo.save(u);
                OTP.remove(email);
                return ResponseEntity.ok(Map.of("status", "OK"));
            }).orElse(ResponseEntity.status(404).body(Map.of("error", "not_found")));
        }
        return ResponseEntity.status(400).body(Map.of("error", "invalid_otp"));
    }
}
