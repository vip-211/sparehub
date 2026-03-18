
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

import java.math.BigDecimal;

import com.spareparts.inventory.entity.Category;
import com.spareparts.inventory.repository.CategoryRepository;

@SpringBootApplication
public class InventoryApplication {
    public static void main(String[] args) {
        SpringApplication.run(InventoryApplication.class, args);
    }

    @Bean
    CommandLineRunner init(RoleRepository roleRepository, UserRepository userRepository, ProductRepository productRepository, CategoryRepository categoryRepository, PasswordEncoder passwordEncoder) {
        return args -> {
            try {
                // Fix existing null deleted flags
                userRepository.findAll().forEach(u -> {
                    if (!u.isDeleted()) {
                        u.setDeleted(false);
                        userRepository.save(u);
                    }
                });
                productRepository.findAll().forEach(p -> {
                    if (!p.isDeleted()) {
                        p.setDeleted(false);
                        productRepository.save(p);
                    }
                });

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

                // Seed Categories if none exist
                Category chainKitCat = null;
                if (categoryRepository.count() == 0) {
                    Category c1 = new Category();
                    c1.setName("Engine Oil");
                    c1.setDescription("Premium quality oils for all engines");
                    categoryRepository.save(c1);

                    Category c2 = new Category();
                    c2.setName("Brake Pads");
                    c2.setDescription("Durable brake pads and shoes");
                    categoryRepository.save(c2);

                    Category c3 = new Category();
                    c3.setName("Chain Kit");
                    c3.setDescription("High performance chain and sprocket kits");
                    chainKitCat = categoryRepository.save(c3);
                } else {
                    chainKitCat = categoryRepository.findAll().stream()
                            .filter(c -> "Chain Kit".equals(c.getName()))
                            .findFirst()
                            .orElse(null);
                }

                // Seed sample products if none exist
                if (productRepository.count() == 0 && wholesaler != null) {
                    Product p1 = new Product();
                    p1.setName("Engine Oil 5W-30");
                    p1.setPartNumber("EO-5W30-001");
                    p1.setRackNumber("A-101");
                    p1.setMrp(new BigDecimal("1200.0"));
                    p1.setSellingPrice(new BigDecimal("950.0"));
                    p1.setWholesalerPrice(new BigDecimal("800.0"));
                    p1.setRetailerPrice(new BigDecimal("850.0"));
                    p1.setMechanicPrice(new BigDecimal("900.0"));
                    p1.setStock(50);
                    p1.setWholesaler(wholesaler);
                    p1.setCategory(chainKitCat); // Just assigning to a category for demo
                    productRepository.save(p1);
                }
            } catch (Exception e) {
                System.err.println("Initialization failed: " + e.getMessage());
                e.printStackTrace();
                // Do not rethrow, allow app to start even if init fails
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
