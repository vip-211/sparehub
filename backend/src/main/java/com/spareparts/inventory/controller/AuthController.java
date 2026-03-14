
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.JwtResponse;
import com.spareparts.inventory.dto.LoginRequest;
import com.spareparts.inventory.dto.MessageResponse;
import com.spareparts.inventory.dto.SignupRequest;
import com.spareparts.inventory.entity.Role;
import com.spareparts.inventory.entity.RoleName;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.RoleRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.security.JwtUtils;
import com.spareparts.inventory.security.UserDetailsImpl;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@CrossOrigin(origins = "*", maxAge = 3600)
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
    PasswordEncoder encoder;

    @Autowired
    JwtUtils jwtUtils;

    @Autowired
    private JavaMailSender mailSender;

    private static final Map<String, String> OTP_STORAGE = new java.util.concurrent.ConcurrentHashMap<>();

    @Value("${spring.mail.username}")
    private String mailFrom;

    @Value("${app.otp.demo-mode:false}")
    private boolean isDemoMode;

    @PostMapping("/send-otp")
    public ResponseEntity<?> sendOtp(@RequestBody Map<String, String> body) {
        String email = body.get("email");
        
        if (email == null || !email.contains("@")) {
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid email address."));
        }
        
        // Generate a 6-digit OTP
        String otp = isDemoMode ? "123456" : String.format("%06d", new java.util.Random().nextInt(999999));
        
        // Skip sending email if in Demo Mode
        if (isDemoMode) {
            OTP_STORAGE.put(email, otp);
            System.out.println("DEMO MODE: OTP for " + email + " is " + otp);
            return ResponseEntity.ok(new MessageResponse("Demo mode: Use OTP 123456 for " + email));
        }
        
        // Send OTP via Email
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(mailFrom);
            message.setTo(email);
            message.setSubject("Your OTP for Spare Parts App");
            message.setText("Your OTP is: " + otp + "\n\nThis OTP is valid for 5 minutes.");
            mailSender.send(message);
            
            OTP_STORAGE.put(email, otp);
            System.out.println("OTP for " + email + ": " + otp);
            
            return ResponseEntity.ok(new MessageResponse("OTP sent successfully to " + email));
        } catch (Exception e) {
            System.err.println("FAILED to send email to " + email + ": " + e.getMessage());
            // Fallback: Still store the OTP and allow the user to use it if they check the logs or response
            OTP_STORAGE.put(email, otp);
            System.out.println("FALLBACK: OTP for " + email + " is " + otp);
            
            return ResponseEntity.ok(new MessageResponse("Mail server connection failed, but you can use this OTP for testing: " + otp));
        }
    }

    @PostMapping("/otp-login")
    public ResponseEntity<?> otpLogin(@RequestBody Map<String, String> body) {
        String email = body.get("email");
        String otp = body.get("otp");

        if (email == null || otp == null) {
            return ResponseEntity.badRequest().body(new MessageResponse("Email and OTP are required."));
        }

        String storedOtp = OTP_STORAGE.get(email);
        if (storedOtp == null || !storedOtp.equals(otp)) {
            return ResponseEntity.badRequest().body(new MessageResponse("Invalid or expired OTP."));
        }

        // Remove OTP after use
        OTP_STORAGE.remove(email);

        // Find user
        java.util.Optional<User> userOptional = userRepository.findByEmail(email);
        if (userOptional.isEmpty()) {
            return ResponseEntity.status(404).body(new MessageResponse("User not found with this email."));
        }

        User user = userOptional.get();
        // Generate token manually as we're not using standard authentication manager
        String jwt = jwtUtils.generateJwtTokenFromUsername(user.getEmail());
        
        String roleName = "ROLE_MECHANIC";
        if (user.getRole() != null && user.getRole().getName() != null) {
            roleName = user.getRole().getName().name();
        }
        List<String> roles = List.of(roleName);

        return ResponseEntity.ok(new JwtResponse(jwt,
                user.getId(),
                user.getName(),
                user.getEmail(),
                roles));
    }

    @PostMapping("/signin")
    public ResponseEntity<?> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) {
        System.out.println("Attempting login for: " + loginRequest.getEmail());
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(loginRequest.getEmail(), loginRequest.getPassword()));

            SecurityContextHolder.getContext().setAuthentication(authentication);
            String jwt = jwtUtils.generateJwtToken(authentication);

            UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
            List<String> roles = userDetails.getAuthorities().stream()
                    .map(GrantedAuthority::getAuthority)
                    .collect(Collectors.toList());

            System.out.println("Login successful for: " + loginRequest.getEmail() + " with roles: " + roles);

            return ResponseEntity.ok(new JwtResponse(jwt,
                    userDetails.getId(),
                    userDetails.getUsername(),
                    userDetails.getEmail(),
                    roles));
        } catch (Exception e) {
            System.err.println("Login failed for: " + loginRequest.getEmail() + " error: " + e.getMessage());
            return ResponseEntity.status(401).body(new MessageResponse("Error: Invalid email or password."));
        }
    }

    @PostMapping("/signup")
    public ResponseEntity<?> registerUser(@Valid @RequestBody SignupRequest signUpRequest) {
        if (userRepository.existsByEmail(signUpRequest.getEmail())) {
            return ResponseEntity
                    .badRequest()
                    .body(new MessageResponse("Error: Email is already in use!"));
        }

        // Verify OTP (if provided)
        String storedOtp = OTP_STORAGE.get(signUpRequest.getEmail());
        
        if (signUpRequest.getOtp() != null && !signUpRequest.getOtp().isEmpty()) {
            if (storedOtp == null || !storedOtp.equals(signUpRequest.getOtp())) {
                return ResponseEntity.badRequest().body(new MessageResponse("Invalid or expired OTP."));
            }
            // Remove OTP after use
            OTP_STORAGE.remove(signUpRequest.getEmail());
        }

        // Create new user's account
        User user = new User();
        user.setName(signUpRequest.getName());
        user.setEmail(signUpRequest.getEmail());
        user.setPassword(encoder.encode(signUpRequest.getPassword()));
        String countryCode = signUpRequest.getCountryCode() != null ? signUpRequest.getCountryCode() : "";
        String phone = signUpRequest.getPhone() != null ? signUpRequest.getPhone() : "";
        String fullPhone = countryCode + phone;
        user.setPhone(fullPhone.isEmpty() ? null : fullPhone);
        user.setAddress(signUpRequest.getAddress());

        String strRole = signUpRequest.getRole();
        Role role;

        if (strRole == null) {
            role = roleRepository.findByName(RoleName.ROLE_MECHANIC)
                    .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
        } else {
            switch (strRole.toLowerCase()) {
                case "admin":
                case "role_admin":
                    role = roleRepository.findByName(RoleName.ROLE_ADMIN)
                            .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                    break;
                case "supermanager":
                case "super_manager":
                case "role_super_manager":
                    role = roleRepository.findByName(RoleName.ROLE_SUPER_MANAGER)
                            .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                    break;
                case "wholesaler":
                case "role_wholesaler":
                    role = roleRepository.findByName(RoleName.ROLE_WHOLESALER)
                            .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                    break;
                case "retailer":
                case "role_retailer":
                    role = roleRepository.findByName(RoleName.ROLE_RETAILER)
                            .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                    break;
                case "staff":
                case "role_staff":
                    role = roleRepository.findByName(RoleName.ROLE_STAFF)
                            .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                    break;
                case "mechanic":
                case "role_mechanic":
                    role = roleRepository.findByName(RoleName.ROLE_MECHANIC)
                            .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
                    break;
                default:
                    role = roleRepository.findByName(RoleName.ROLE_MECHANIC)
                            .orElseThrow(() -> new RuntimeException("Error: Role is not found."));
            }
        }

        user.setRole(role);
        // Mechanics, Admins, Staff, and Super Managers are approved by default
        if (role.getName() == RoleName.ROLE_MECHANIC || 
            role.getName() == RoleName.ROLE_ADMIN || 
            role.getName() == RoleName.ROLE_STAFF || 
            role.getName() == RoleName.ROLE_SUPER_MANAGER) {
            user.setStatus(User.UserStatus.ACTIVE);
        } else {
            user.setStatus(User.UserStatus.PENDING);
        }

        userRepository.save(user);

        return ResponseEntity.ok(new MessageResponse("User registered successfully!"));
    }

    @PostMapping("/google")
    public ResponseEntity<?> googleLogin(@RequestBody Map<String, Object> body) {
        String email = String.valueOf(body.get("email"));
        String name = String.valueOf(body.get("name"));
        
        java.util.Optional<User> userOptional = userRepository.findByEmail(email);
        
        User user;
        if (userOptional.isPresent()) {
            user = userOptional.get();
        } else {
            // Create new user if not exists
            user = new User();
            user.setEmail(email);
            user.setName(name);
            user.setPassword(encoder.encode("sso_google_password"));
            
            Role defaultRole = roleRepository.findByName(RoleName.ROLE_RETAILER)
                    .orElseGet(() -> {
                        Role r = new Role();
                        r.setName(RoleName.ROLE_RETAILER);
                        return roleRepository.save(r);
                    });
            
            user.setRole(defaultRole);
            user.setStatus(User.UserStatus.ACTIVE);
            user = userRepository.save(user);
        }

        // Generate token
        String jwt = jwtUtils.generateJwtTokenFromUsername(user.getEmail());
        
        String roleName = "ROLE_MECHANIC";
        if (user.getRole() != null && user.getRole().getName() != null) {
            roleName = user.getRole().getName().name();
        }
        List<String> roles = List.of(roleName);

        return ResponseEntity.ok(new JwtResponse(jwt,
                user.getId(),
                user.getName(),
                user.getEmail(),
                roles));
    }
}
