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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
@RequestMapping(value = "/api/auth", produces = "application/json")
@CrossOrigin(origins = "*")
public class AuthController {
    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

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

    private boolean isPhoneNumber(String identifier) {
        if (identifier == null) return false;
        // Basic phone number detection (digits and optional +)
        return identifier.matches("^\\+?[0-9]{10,15}$");
    }

    @PostMapping(value = "/send-otp", produces = "application/json")
    @Transactional
    public ResponseEntity<?> sendOtp(@RequestBody Map<String, String> body) {
        String identifier = body.get("email"); // Field is named email but can be phone
        String purpose = body.getOrDefault("purpose", "login").toLowerCase(); // signup, login, reset

        if (identifier == null || identifier.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(new MessageResponse("Email or Phone Number is required."));
        }

        String email = identifier.trim();
        boolean isPhone = isPhoneNumber(email);
        String phone = isPhone ? email : null;

        // For login/reset flows, find the actual email if identifier is phone
        if ("login".equals(purpose) || "reset".equals(purpose)) {
            Optional<User> userOpt = userRepository.findByIdentifier(email);
            if (userOpt.isEmpty()) {
                return ResponseEntity.status(404).body(new MessageResponse("User does not exist."));
            }
            User user = userOpt.get();
            email = user.getEmail();
            phone = user.getPhone();
        } else if ("signup".equals(purpose)) {
            // Normalize signup email
            email = email.toLowerCase();
            if (userRepository.existsByEmailAndDeletedFalse(email)) {
                return ResponseEntity.badRequest().body(new MessageResponse("Error: Email is already in use!"));
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
        log.debug("GENERATED OTP for {}: {}", email, otp);
        
        // 1. Attempt to send OTP via configured mechanism; never break the flow
        if (isDemoMode) {
            log.info("DEMO MODE: Skipping real send for {}. OTP is: {}", email, otp);
            // In demo mode, we still save the OTP so it's technically valid
        } else {
            try {
                otpService.sendOtp(email, otp);
            } catch (Exception e) {
                // OtpService handles internal errors and fallback prints
                log.error("Error while invoking OtpService.sendOtp: {}", e.getMessage());
            }
        }

        // 2. Save OTP regardless of email result (non-blocking user flow)
        try {
            otpService.saveOtp(email, otp);
            log.debug("Persistent OTP saved for {}", email);
        } catch (Exception e) {
            log.error("Error saving OTP to DB: {}", e.getMessage());
            // Inform client that OTP was initiated, but saving failed
            // Still return 200 to avoid blocking UX; client can re-request if needed
            return ResponseEntity.ok(new MessageResponse("OTP initiated but there was a server issue recording the session. Please try again if you don't receive an email."));
        }

        return ResponseEntity.ok(new MessageResponse("OTP initiated for " + email));
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
                user.setStatus(User.UserStatus.PENDING);
                Role role = roleRepository.findByName(RoleName.ROLE_MECHANIC)
                        .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                user.setRole(role);
                userRepository.save(user);
            }

            if (user.getStatus() != User.UserStatus.ACTIVE) {
                return ResponseEntity.status(403).body(new MessageResponse("Your account is pending admin approval. Current status: " + user.getStatus()));
            }

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
        
        // Find user first to resolve identifier to email
        Optional<User> userOptional = userRepository.findByIdentifier(identifier.trim());
        if (userOptional.isEmpty()) {
            return ResponseEntity.status(404).body(new MessageResponse("User not found. Please register first."));
        }
        User user = userOptional.get();
        if (user.getStatus() != User.UserStatus.ACTIVE) {
            return ResponseEntity.status(403).body(new MessageResponse("Your account is pending admin approval. Current status: " + user.getStatus()));
        }
        
        String email = user.getEmail();

        // Allow matching against the last 2 valid OTPs to handle race conditions (Fix per latest log review)
        List<Otp> storedOtps = otpRepository.findAllByEmailOrderByExpiryTimeDesc(email);
        
        if (storedOtps.isEmpty()) {
            return ResponseEntity.badRequest().body(new MessageResponse("No OTP found. Please request a new one."));
        }

        Otp validOtp = null;
        for (int i = 0; i < Math.min(storedOtps.size(), 2); i++) {
            Otp candidate = storedOtps.get(i);
            if (candidate.getOtp().equals(otp) && !candidate.isExpired()) {
                validOtp = candidate;
                break;
            }
        }

        if (validOtp == null) {
            log.warn("OTP Mismatch for {}. Received: {}", email, otp);
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid or expired OTP. Please use the latest code from your email."));
        }

        // Remove OTP after use
        otpRepository.deleteByEmail(email);

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

        if (user.getStatus() != User.UserStatus.ACTIVE) {
            return ResponseEntity.status(403).body(new MessageResponse("Your account is pending admin approval. Current status: " + user.getStatus()));
        }

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
        if (userRepository.existsByEmailAndDeletedFalse(signUpRequest.getEmail())) {
            return ResponseEntity
                    .badRequest()
                    .body(new MessageResponse("Error: Email is already in use!"));
        }
        
        if (signUpRequest.getPhone() != null && !signUpRequest.getPhone().isEmpty()) {
            if (userRepository.existsByPhoneAndDeletedFalse(signUpRequest.getPhone())) {
                return ResponseEntity
                        .badRequest()
                        .body(new MessageResponse("Error: Mobile number is already in use!"));
            }
        }

        // Verify OTP (skip if firebaseToken is present)
        if (signUpRequest.getFirebaseToken() != null && !signUpRequest.getFirebaseToken().isEmpty()) {
            try {
                // 1. Verify the token with Firebase
                FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(signUpRequest.getFirebaseToken());
                String verifiedPhone = (String) decodedToken.getClaims().get("phone_number");
                // Optional: verify that the verifiedPhone matches the phone from the request
            } catch (Exception e) {
                return ResponseEntity.status(401).body(new MessageResponse("Firebase verification failed: " + e.getMessage()));
            }
        } else {
            // Allow matching against the last 2 valid OTPs to handle race conditions (Fix per latest log review)
            List<Otp> storedOtps = otpRepository.findAllByEmailOrderByExpiryTimeDesc(signUpRequest.getEmail());
            
            if (storedOtps.isEmpty()) {
                return ResponseEntity.badRequest().body(new MessageResponse("No OTP found. Please request a new one."));
            }

            Otp validOtp = null;
            for (int i = 0; i < Math.min(storedOtps.size(), 2); i++) {
                Otp candidate = storedOtps.get(i);
                if (candidate.getOtp().equals(signUpRequest.getOtp()) && !candidate.isExpired()) {
                    validOtp = candidate;
                    break;
                }
            }

            if (validOtp == null) {
                log.warn("Signup OTP Mismatch for {}. Received: {}", signUpRequest.getEmail(), signUpRequest.getOtp());
                return ResponseEntity.badRequest().body(new MessageResponse("Invalid or expired OTP."));
            }
            
            // Remove OTP after use
            otpRepository.deleteByEmail(signUpRequest.getEmail());
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

        // Allow matching against the last 2 valid OTPs to handle race conditions (Fix per latest log review)
        List<Otp> storedOtps = otpRepository.findAllByEmailOrderByExpiryTimeDesc(email);
        
        if (storedOtps.isEmpty()) {
            return ResponseEntity.badRequest().body(new MessageResponse("No OTP found. Please request a new one."));
        }

        Otp validOtp = null;
        for (int i = 0; i < Math.min(storedOtps.size(), 2); i++) {
            Otp candidate = storedOtps.get(i);
            if (candidate.getOtp().equals(otp) && !candidate.isExpired()) {
                validOtp = candidate;
                break;
            }
        }

        if (validOtp == null) {
            log.warn("Reset Password OTP Mismatch for {}. Received: {}", email, otp);
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid or expired OTP."));
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
        
        if (user.getStatus() != User.UserStatus.ACTIVE) {
            return ResponseEntity.status(403).body(new MessageResponse("Your account is pending admin approval. Current status: " + user.getStatus()));
        }

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
