
package com.spareparts.inventory;

import com.spareparts.inventory.entity.Role;
import com.spareparts.inventory.entity.RoleName;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.RoleRepository;
import com.spareparts.inventory.repository.UserRepository;
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
    CommandLineRunner init(RoleRepository roleRepository, UserRepository userRepository, PasswordEncoder passwordEncoder) {
        return args -> {
            // Check and create roles if they don't exist
            for (RoleName roleName : RoleName.values()) {
                if (roleRepository.findByName(roleName).isEmpty()) {
                    roleRepository.save(new Role(null, roleName));
                }
            }

            // Create test users if they don't exist
            String defaultPassword = passwordEncoder.encode("password123");

            if (userRepository.findByEmail("supermanager@example.com").isEmpty()) {
                Role superManagerRole = roleRepository.findByName(RoleName.ROLE_SUPER_MANAGER).orElseThrow();
                User superManager = new User();
                superManager.setName("Super Manager");
                superManager.setEmail("supermanager@example.com");
                superManager.setPassword(defaultPassword);
                superManager.setPhone("9999999999");
                superManager.setAddress("Super Manager HQ");
                superManager.setRole(superManagerRole);
                superManager.setStatus(User.UserStatus.ACTIVE);
                userRepository.save(superManager);
            } else {
                userRepository.findByEmail("supermanager@example.com").ifPresent(u -> {
                    Role superManagerRole = roleRepository.findByName(RoleName.ROLE_SUPER_MANAGER).orElseThrow();
                    u.setRole(superManagerRole);
                    u.setStatus(User.UserStatus.ACTIVE);
                    u.setPassword(defaultPassword); // Reset to password123 for troubleshooting
                    userRepository.save(u);
                });
            }

            if (userRepository.findByEmail("super.manager@example.com").isEmpty()) {
                Role superManagerRole = roleRepository.findByName(RoleName.ROLE_SUPER_MANAGER).orElseThrow();
                User superManager = new User();
                superManager.setName("Super Manager Dot");
                superManager.setEmail("super.manager@example.com");
                superManager.setPassword(defaultPassword);
                superManager.setPhone("9999999998");
                superManager.setAddress("Super Manager HQ");
                superManager.setRole(superManagerRole);
                superManager.setStatus(User.UserStatus.ACTIVE);
                userRepository.save(superManager);
            } else {
                // Ensure role is set for existing user
                userRepository.findByEmail("super.manager@example.com").ifPresent(u -> {
                    if (u.getRole() == null) {
                        Role superManagerRole = roleRepository.findByName(RoleName.ROLE_SUPER_MANAGER).orElseThrow();
                        u.setRole(superManagerRole);
                        u.setStatus(User.UserStatus.ACTIVE);
                        userRepository.save(u);
                    }
                });
            }

            if (userRepository.findByEmail("admin@example.com").isEmpty()) {
                Role adminRole = roleRepository.findByName(RoleName.ROLE_ADMIN).orElseThrow();
                User admin = new User();
                admin.setName("System Admin");
                admin.setEmail("admin@example.com");
                admin.setPassword(defaultPassword);
                admin.setPhone("1234567890");
                admin.setAddress("Admin Address");
                admin.setRole(adminRole);
                admin.setStatus(User.UserStatus.ACTIVE);
                userRepository.save(admin);
            } else {
                userRepository.findByEmail("admin@example.com").ifPresent(u -> {
                    u.setPassword(defaultPassword);
                    userRepository.save(u);
                });
            }

            if (userRepository.findByEmail("wholesaler@example.com").isEmpty()) {
                Role wholesalerRole = roleRepository.findByName(RoleName.ROLE_WHOLESALER).orElseThrow();
                User wholesaler = new User();
                wholesaler.setName("Best Wholesaler");
                wholesaler.setEmail("wholesaler@example.com");
                wholesaler.setPassword(defaultPassword);
                wholesaler.setPhone("1234567890");
                wholesaler.setAddress("Wholesaler Address");
                wholesaler.setRole(wholesalerRole);
                wholesaler.setStatus(User.UserStatus.ACTIVE);
                userRepository.save(wholesaler);
            }

            if (userRepository.findByEmail("retailer@example.com").isEmpty()) {
                Role retailerRole = roleRepository.findByName(RoleName.ROLE_RETAILER).orElseThrow();
                User retailer = new User();
                retailer.setName("City Retailer");
                retailer.setEmail("retailer@example.com");
                retailer.setPassword(defaultPassword);
                retailer.setPhone("1234567890");
                retailer.setAddress("Retailer Address");
                retailer.setRole(retailerRole);
                retailer.setStatus(User.UserStatus.ACTIVE);
                userRepository.save(retailer);
            }

            if (userRepository.findByEmail("mechanic@example.com").isEmpty()) {
                Role mechanicRole = roleRepository.findByName(RoleName.ROLE_MECHANIC).orElseThrow();
                User mechanic = new User();
                mechanic.setName("Expert Mechanic");
                mechanic.setEmail("mechanic@example.com");
                mechanic.setPassword(defaultPassword);
                mechanic.setPhone("1234567890");
                mechanic.setAddress("Mechanic Address");
                mechanic.setRole(mechanicRole);
                mechanic.setStatus(User.UserStatus.ACTIVE);
                userRepository.save(mechanic);
            }
        };
    }
}
