
package com.spareparts.inventory;

import com.spareparts.inventory.entity.Role;
import com.spareparts.inventory.entity.RoleName;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.RoleRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.ProductRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.security.crypto.password.PasswordEncoder;

@SpringBootApplication
public class InventoryApplication {
    public static void main(String[] args) {
        SpringApplication.run(InventoryApplication.class, args);
    }

    @Bean
    CommandLineRunner init(RoleRepository roleRepository, UserRepository userRepository, ProductRepository productRepository, PasswordEncoder passwordEncoder) {
        return args -> {
            // Check and create roles if they don't exist
            java.util.Map<RoleName, Role> roles = new java.util.HashMap<>();
            for (RoleName roleName : RoleName.values()) {
                Role role = roleRepository.findByName(roleName).orElseGet(() -> {
                    Role newRole = new Role(null, roleName);
                    return roleRepository.save(newRole);
                });
                roles.put(roleName, role);
            }

            // Create test users if they don't exist
            String defaultPassword = passwordEncoder.encode("password123");

            User superManager = autoCreateUser(userRepository, "supermanager@example.com", "Super Manager", defaultPassword, "9999999999", roles.get(RoleName.ROLE_SUPER_MANAGER));
            autoCreateUser(userRepository, "super.manager@example.com", "Super Manager Dot", defaultPassword, "9999999998", roles.get(RoleName.ROLE_SUPER_MANAGER));
            User admin = autoCreateUser(userRepository, "admin@example.com", "System Admin", defaultPassword, "1234567890", roles.get(RoleName.ROLE_ADMIN));
            User wholesaler = autoCreateUser(userRepository, "wholesaler@example.com", "Best Wholesaler", defaultPassword, "1234567891", roles.get(RoleName.ROLE_WHOLESALER));
            autoCreateUser(userRepository, "retailer@example.com", "City Retailer", defaultPassword, "1234567892", roles.get(RoleName.ROLE_RETAILER));
            autoCreateUser(userRepository, "mechanic@example.com", "Expert Mechanic", defaultPassword, "1234567893", roles.get(RoleName.ROLE_MECHANIC));

            // Seed sample products if none exist
            if (productRepository.count() == 0 && wholesaler != null) {
                Product p1 = new Product();
                p1.setName("Engine Oil 5W-30");
                p1.setPartNumber("EO-5W30-001");
                p1.setRackNumber("A-101");
                p1.setMrp(1200.0);
                p1.setSellingPrice(950.0);
                p1.setWholesalerPrice(800.0);
                p1.setRetailerPrice(850.0);
                p1.setMechanicPrice(900.0);
                p1.setStock(50);
                p1.setEnabled(true);
                p1.setDeleted(false);
                p1.setWholesaler(wholesaler);
                productRepository.save(p1);

                Product p2 = new Product();
                p2.setName("Brake Pads Front");
                p2.setPartNumber("BP-F-002");
                p2.setRackNumber("B-205");
                p2.setMrp(2500.0);
                p2.setSellingPrice(1800.0);
                p2.setWholesalerPrice(1400.0);
                p2.setRetailerPrice(1550.0);
                p2.setMechanicPrice(1650.0);
                p2.setStock(20);
                p2.setEnabled(true);
                p2.setDeleted(false);
                p2.setWholesaler(wholesaler);
                productRepository.save(p2);
            }
        };
    }

    private User autoCreateUser(UserRepository userRepository, String email, String name, String password, String phone, Role role) {
        java.util.Optional<User> existing = userRepository.findByEmail(email);
        if (existing.isEmpty()) {
            User user = new User();
            user.setName(name);
            user.setEmail(email);
            user.setPassword(password);
            user.setPhone(phone);
            user.setAddress("System Default Address");
            user.setRole(role);
            user.setStatus(User.UserStatus.ACTIVE);
            return userRepository.save(user);
        }
        return existing.get();
    }
}
