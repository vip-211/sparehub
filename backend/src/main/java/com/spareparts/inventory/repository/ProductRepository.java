
package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
    List<Product> findByWholesalerAndDeletedFalse(User wholesaler);
    List<Product> findByWholesalerAndDeletedTrue(User wholesaler);
    Optional<Product> findByPartNumberAndDeletedFalse(String partNumber);
    @org.springframework.data.jpa.repository.Query("SELECT p FROM Product p WHERE (LOWER(p.name) LIKE LOWER(CONCAT('%', :query, '%')) OR LOWER(p.partNumber) LIKE LOWER(CONCAT('%', :query, '%'))) AND p.deleted = false")
    List<Product> searchProducts(@org.springframework.data.repository.query.Param("query") String query);
    
    List<Product> findByCategory_IdAndDeletedFalse(Long categoryId);
    List<Product> findByDeletedFalse();
    List<Product> findByDeletedTrue();

    // Legacy support for older code
    default List<Product> findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(String name, String partNumber) {
        return searchProducts(name); // Assuming name is the query
    }
}
