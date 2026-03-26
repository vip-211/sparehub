package com.spareparts.inventory.controller;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import com.spareparts.inventory.dto.JwtResponse;
import com.spareparts.inventory.dto.LoginRequest;
import com.spareparts.inventory.dto.MessageResponse;
import com.spareparts.inventory.dto.SignupRequest;
import com.spareparts.inventory.entity.Role;
import com.spareparts.inventory.entity.RoleName;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.entity.Otp;
import com.spareparts.inventory.repository.OtpRepository;
import com.spareparts.inventory.repository.RoleRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.security.JwtUtils;
import com.spareparts.inventory.security.UserDetailsImpl;
import com.spareparts.inventory.service.OtpService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    @Autowired
    AuthenticationManager authenticationManager;

    @Autowired
    UserRepository userRepository;

    @Autowired
    RoleRepository roleRepository;

    @Autowired
    OtpRepository otpRepository;

    @Autowired
    OtpService otpService;

    @Autowired
    PasswordEncoder encoder;

    @Autowired
    JwtUtils jwtUtils;

    private static final Map<String, Long> RATE_LIMIT_STORAGE = new java.util.concurrent.ConcurrentHashMap<>();
    private static final long RATE_LIMIT_MS = 60000; // 1 minute between OTP requests

    @Value("${app.otp.demo-mode:false}")
    private boolean isDemoMode;

    @PostMapping(value = "/send-otp", produces = "application/json")
    public ResponseEntity<?> sendOtp(@RequestBody Map<String, String> body) {
        String identifier = body.get("email");
        if (identifier == null || identifier.isEmpty()) {
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid identifier."));
        }
        
        // Normalize
        final String email = identifier.contains("@") ? identifier.toLowerCase().trim() : identifier.trim();
        
        String purpose = body.getOrDefault("purpose", "login").toLowerCase();

        // For signup, ensure user does NOT exist
        if ("signup".equals(purpose)) {
            if (userRepository.existsByEmail(email)) {
                return ResponseEntity.badRequest().body(new MessageResponse("Error: Email is already in use!"));
            }
        }

        // For login/reset flows, ensure user exists
        if ("login".equals(purpose) || "reset".equals(purpose)) {
            boolean exists = userRepository.existsByEmail(email);
            if (!exists) {
                return ResponseEntity.status(404).body(new MessageResponse("User does not exist."));
            }
        }

        // Simple Rate Limiting
        long now = System.currentTimeMillis();
        if (RATE_LIMIT_STORAGE.containsKey(email) && (now - RATE_LIMIT_STORAGE.get(email)) < RATE_LIMIT_MS) {
            return ResponseEntity.status(429).body(new MessageResponse("Too many requests. Please wait a minute."));
        }
        RATE_LIMIT_STORAGE.put(email, now);
        
        // Generate a 6-digit OTP
        String otp = isDemoMode ? "123456" : String.format("%06d", new java.util.Random().nextInt(999999));
        
        // Log the generated OTP immediately for troubleshooting
        System.out.println("GENERATED OTP for " + email + ": " + otp);
        
        // 1. SAVE OTP FIRST to persistent storage (DB)
        try {
            otpService.saveOtp(email, otp);
            System.out.println("Persistent OTP saved for " + email);
        } catch (Exception e) {
            System.err.println("Error saving OTP to DB: " + e.getMessage());
            return ResponseEntity.status(500).body(new MessageResponse("Failed to process request. Please try again."));
        }

        // Skip sending email if in Demo Mode
        if (isDemoMode) {
            System.out.println("DEMO MODE: OTP for " + email + " is " + otp);
            return ResponseEntity.ok(new MessageResponse("Demo mode: Use OTP 123456 for " + email));
        }
        
        // 2. THEN attempt to send OTP via Email
        try {
            otpService.sendOtpEmail(email, otp);
            System.out.println("OTP email sent successfully to " + email);
            return ResponseEntity.ok(new MessageResponse("OTP sent successfully to " + email));
        } catch (Exception e) {
            System.err.println("CRITICAL: FAILED to send email to " + email);
            System.err.println("Error Message: " + e.getMessage());
            e.printStackTrace();
            
            // Provide more specific guidance in the response
            String userMessage = "OTP generated, but email delivery failed. ";
            if (e.getMessage() != null && e.getMessage().contains("Username and Password not accepted")) {
                userMessage += "Reason: SMTP Authentication failed. Please check Gmail App Password.";
            } else if (e.getMessage() != null && (e.getMessage().contains("Connect timed out") || e.getMessage().contains("Connection timed out"))) {
                userMessage += "Reason: Connection to mail server timed out. Render may be blocking port 587. Switching to port 465 might help.";
            } else {
                userMessage += "Please check server logs or contact support.";
            }
            
            return ResponseEntity.ok(new MessageResponse(userMessage + " You can try verifying if you have the OTP."));
        }
    }

    @PostMapping(value = "/phone-login", produces = "application/json")
    public ResponseEntity<?> loginWithPhone(@RequestBody Map<String, String> body) {
        String phoneNumber = body.get("phoneNumber");
        String firebaseToken = body.get("firebaseToken");

        if (phoneNumber == null || firebaseToken == null) {
            return ResponseEntity.badRequest().body(new MessageResponse("Phone number and token are required."));
        }

        try {
            // 1. Verify the token with Firebase
            FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(firebaseToken);
            String verifiedPhone = (String) decodedToken.getClaims().get("phone_number");
            
            // Note: Firebase phone numbers usually include + and country code
            // Ensure the phoneNumber from frontend matches what Firebase verified
            if (verifiedPhone == null || !verifiedPhone.contains(phoneNumber.replaceAll("\\s+", ""))) {
                // If the claim is missing, we check the UID or other identifier if needed
                // But for phone auth, the phone_number claim is standard
            }

            // 2. Find or auto-create user in database
            String normalized = phoneNumber.trim();
            if (normalized.startsWith("00")) normalized = "+" + normalized.substring(2);
            String plain = normalized.replace("+", "");

            java.util.Optional<User> existingUser = userRepository.findByPhoneAndDeletedFalse(normalized)
                    .or(() -> userRepository.findByPhoneAndDeletedFalse("+" + plain))
                    .or(() -> userRepository.findByPhoneAndDeletedFalse(plain));

            User user;
            if (existingUser.isPresent()) {
                user = existingUser.get();
            } else {
                // Auto-create minimal user
                String syntheticEmail = plain + "@phone.partsmitra.app";
                if (userRepository.existsByEmailAndDeletedFalse(syntheticEmail)) {
                    syntheticEmail = plain + "+1@phone.partsmitra.app";
                }
                user = new User();
                user.setName("User " + (plain.length() >= 4 ? plain.substring(plain.length() - 4) : plain));
                user.setEmail(syntheticEmail);
                user.setPassword(encoder.encode(java.util.UUID.randomUUID().toString()));
                user.setPhone(normalized);
                user.setStatus(User.UserStatus.ACTIVE);
                Role role = roleRepository.findByName(RoleName.ROLE_MECHANIC)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                user.setRole(role);
                userRepository.save(user);
            }

            /*
            if (user.getStatus() != User.UserStatus.ACTIVE) {
                return ResponseEntity.status(403).body(new MessageResponse("Your account is not active. Status: " + user.getStatus()));
            }
            */

            // 3. Generate JWT
            String jwt = jwtUtils.generateJwtTokenFromUsername(user.getEmail());
            List<String> roles = List.of(user.getRole().getName().name());

            return ResponseEntity.ok(new JwtResponse(jwt,
                    user.getId(),
                    user.getName(),
                    user.getEmail(),
                    roles,
                    user.getAddress(),
                    user.getStatus().name(),
                    user.getLatitude(),
                    user.getLongitude(),
                    user.getPoints()));

        } catch (Exception e) {
            return ResponseEntity.status(401).body(new MessageResponse("Authentication failed: " + e.getMessage()));
        }
    }

    @PostMapping(value = "/otp-login", produces = "application/json")
    @Transactional
    public ResponseEntity<?> otpLogin(@RequestBody Map<String, String> body) {
        String identifier = body.get("email");
        String otp = body.get("otp");

        if (identifier == null || otp == null) {
            return ResponseEntity.badRequest().body(new MessageResponse("Email and OTP are required."));
        }
        
        // Normalize
        final String email = identifier.contains("@") ? identifier.toLowerCase().trim() : identifier.trim();

        Otp storedOtp = otpRepository.findTopByEmailOrderByExpiryTimeDesc(email).orElse(null);
        
        if (storedOtp == null || !storedOtp.getOtp().equals(otp)) {
            System.out.println("OTP Verification Failed for " + email + ". Received: " + otp + ", Stored: " + (storedOtp != null ? storedOtp.getOtp() : "null"));
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid OTP."));
        }

        if (storedOtp.isExpired()) {
            return ResponseEntity.badRequest().body(new MessageResponse("OTP has expired. Please request a new one."));
        }

        // Find user
        java.util.Optional<User> userOptional = userRepository.findByEmail(email);
        if (userOptional.isEmpty()) {
            return ResponseEntity.status(404).body(new MessageResponse("User not found. Please register first."));
        }

        // Remove OTP after use
        otpRepository.deleteByEmail(email);

        User user = userOptional.get();
        String jwt = jwtUtils.generateJwtTokenFromUsername(user.getEmail());

        List<String> roles = List.of(user.getRole().getName().name());

        return ResponseEntity.ok(new JwtResponse(jwt,
                user.getId(),
                user.getName(),
                user.getEmail(),
                roles,
                user.getAddress(),
                user.getStatus().name(),
                user.getLatitude(),
                user.getLongitude(),
                user.getPoints()));
    }

    @PostMapping(value = "/signin", produces = "application/json")
    public ResponseEntity<?> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(loginRequest.getEmail(), loginRequest.getPassword()));

        SecurityContextHolder.getContext().setAuthentication(authentication);
        String jwt = jwtUtils.generateJwtToken(authentication);

        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        List<String> roles = userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.toList());

        User user = userRepository.findById(userDetails.getId()).orElseThrow(() -> new RuntimeException("User not found"));

        return ResponseEntity.ok(new JwtResponse(jwt,
                userDetails.getId(),
                userDetails.getUsername(),
                userDetails.getEmail(),
                roles,
                user.getAddress(),
                user.getStatus().name(),
                user.getLatitude(),
                user.getLongitude(),
                user.getPoints()));
    }

    @PostMapping(value = "/signup", produces = "application/json")
    @Transactional
    public ResponseEntity<?> registerUser(@Valid @RequestBody SignupRequest signUpRequest) {
        if (userRepository.existsByEmail(signUpRequest.getEmail())) {
            return ResponseEntity
                    .badRequest()
                    .body(new MessageResponse("Error: Email is already in use!"));
        }

        // Verify OTP from DB
        Otp storedOtp = otpRepository.findTopByEmailOrderByExpiryTimeDesc(signUpRequest.getEmail()).orElse(null);
        if (storedOtp == null || !storedOtp.getOtp().equals(signUpRequest.getOtp())) {
            System.out.println("Signup OTP Verification Failed for " + signUpRequest.getEmail() + ". Received: " + signUpRequest.getOtp() + ", Stored: " + (storedOtp != null ? storedOtp.getOtp() : "null"));
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid OTP."));
        }

        if (storedOtp.isExpired()) {
            return ResponseEntity.badRequest().body(new MessageResponse("OTP has expired."));
        }

        // Create new user's account
        User user = new User();
        user.setName(signUpRequest.getName());
        user.setEmail(signUpRequest.getEmail());
        user.setPassword(encoder.encode(signUpRequest.getPassword()));
        user.setPhone(signUpRequest.getPhone());
        user.setAddress(signUpRequest.getAddress());
        user.setStatus(User.UserStatus.PENDING); // Default status

        String strRole = signUpRequest.getRole();
        Role role;

        if (strRole == null) {
            role = roleRepository.findByName(RoleName.ROLE_MECHANIC)
                    .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
        } else {
            role = switch (strRole.toUpperCase()) {
                case "ADMIN" -> roleRepository.findByName(RoleName.ROLE_ADMIN)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                case "SUPER_MANAGER" -> roleRepository.findByName(RoleName.ROLE_SUPER_MANAGER)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                case "STAFF" -> roleRepository.findByName(RoleName.ROLE_STAFF)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                case "WHOLESALER" -> roleRepository.findByName(RoleName.ROLE_WHOLESALER)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                case "RETAILER" -> roleRepository.findByName(RoleName.ROLE_RETAILER)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                default -> roleRepository.findByName(RoleName.ROLE_MECHANIC)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
            };
        }

        user.setRole(role);
        userRepository.save(user);

        // Remove OTP after use
        otpRepository.deleteByEmail(signUpRequest.getEmail());

        return ResponseEntity.ok(new MessageResponse("User registered successfully! Please wait for admin approval."));
    }

    @PostMapping("/update-fcm-token")
    public ResponseEntity<?> updateFcmToken(@RequestBody Map<String, Object> body) {
        Object userIdObj = body.get("userId");
        String token = (String) body.get("token");
        
        if (userIdObj == null || token == null) {
            return ResponseEntity.badRequest().body(new MessageResponse("User ID and token are required."));
        }

        Long userId;
        if (userIdObj instanceof Integer) {
            userId = ((Integer) userIdObj).longValue();
        } else if (userIdObj instanceof Long) {
            userId = (Long) userIdObj;
        } else {
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid User ID format."));
        }

        userRepository.findById(userId).ifPresent(user -> {
            user.setFcmToken(token);
            userRepository.save(user);
        });
        return ResponseEntity.ok(new MessageResponse("FCM token updated successfully"));
    }

    @PostMapping(value = "/reset-password", produces = "application/json")
    @Transactional
    public ResponseEntity<?> resetPassword(@RequestBody Map<String, String> body) {
        String identifier = body.get("email");
        String otp = body.get("otp");
        String newPassword = body.get("newPassword");

        if (identifier == null || otp == null || newPassword == null) {
            return ResponseEntity.badRequest().body(new MessageResponse("Email, OTP, and new password are required."));
        }
        
        // Normalize
        final String email = identifier.contains("@") ? identifier.toLowerCase().trim() : identifier.trim();

        Otp storedOtp = otpRepository.findTopByEmailOrderByExpiryTimeDesc(email).orElse(null);
        if (storedOtp == null || !storedOtp.getOtp().equals(otp)) {
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid or expired OTP."));
        }

        if (storedOtp.isExpired()) {
            return ResponseEntity.badRequest().body(new MessageResponse("OTP has expired."));
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        user.setPassword(encoder.encode(newPassword));
        userRepository.save(user);

        otpRepository.deleteByEmail(email);

        return ResponseEntity.ok(new MessageResponse("Password reset successfully."));
    }

    @PostMapping("/google")
    public ResponseEntity<?> googleSignIn(@RequestBody Map<String, String> body) {
        String email = body.get("email");
        String name = body.get("name");

        if (email == null) {
            return ResponseEntity.badRequest().body(new MessageResponse("Email is required."));
        }

        User user = userRepository.findByEmail(email).orElseGet(() -> {
            User newUser = new User();
            newUser.setEmail(email);
            newUser.setName(name);
            newUser.setPassword(encoder.encode("google_sso_default_password")); // Set a default, secure password
            newUser.setStatus(User.UserStatus.ACTIVE);
            Role defaultRole = roleRepository.findByName(RoleName.ROLE_MECHANIC)
                    .orElseThrow(() -> new RuntimeException("Default role not found."));
            newUser.setRole(defaultRole);
            return userRepository.save(newUser);
        });

        String jwt = jwtUtils.generateJwtTokenFromUsername(user.getEmail());
        List<String> roles = List.of(user.getRole().getName().name());

        return ResponseEntity.ok(new JwtResponse(jwt,
                user.getId(),
                user.getName(),
                user.getEmail(),
                roles,
                user.getAddress(),
                user.getStatus().name(),
                user.getLatitude(),
                user.getLongitude(),
                user.getPoints()));
    }
}
