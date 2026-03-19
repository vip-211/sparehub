
package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmailAndDeletedFalse(String email);
    Optional<User> findByPhoneAndDeletedFalse(String phone);
    Boolean existsByEmailAndDeletedFalse(String email);
    Boolean existsByPhoneAndDeletedFalse(String phone);
    java.util.List<User> findByDeletedFalse();
    java.util.List<User> findByDeletedTrue();

    // Legacy support for older code
    default Optional<User> findByEmail(String email) {
        return findByEmailAndDeletedFalse(email);
    }

    default Boolean existsByEmail(String email) {
        return existsByEmailAndDeletedFalse(email);
    }
}
