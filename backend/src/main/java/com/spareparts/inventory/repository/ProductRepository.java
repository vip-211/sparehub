
package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
    List<Product> findByWholesalerAndDeletedFalse(User wholesaler);
    Page<Product> findByWholesalerAndDeletedFalse(User wholesaler, Pageable pageable);
    List<Product> findByWholesalerAndDeletedTrue(User wholesaler);
    Optional<Product> findByPartNumberAndDeletedFalse(String partNumber);
    Optional<Product> findByPartNumberAndWholesalerAndDeletedFalse(String partNumber, User wholesaler);
    
    @Query("SELECT p FROM Product p WHERE (LOWER(p.name) LIKE LOWER(CONCAT('%', :query, '%')) OR LOWER(p.partNumber) LIKE LOWER(CONCAT('%', :query, '%'))) AND p.deleted = false")
    List<Product> searchProducts(@Param("query") String query);
    
    @Query("SELECT p FROM Product p WHERE (LOWER(p.name) LIKE LOWER(CONCAT('%', :query, '%')) OR LOWER(p.partNumber) LIKE LOWER(CONCAT('%', :query, '%'))) AND p.deleted = false")
    Page<Product> searchProducts(@Param("query") String query, Pageable pageable);
    
    List<Product> findByCategory_IdAndDeletedFalse(Long categoryId);
    Page<Product> findByCategory_IdAndDeletedFalse(Long categoryId, Pageable pageable);
    
    List<Product> findByDeletedFalse();
    Page<Product> findByDeletedFalse(Pageable pageable);
    
    List<Product> findByDeletedTrue();
    
    List<Product> findByFeaturedTrueAndDeletedFalse();
    
    List<Product> findByOfferTypeAndDeletedFalse(Product.OfferType offerType);
    Page<Product> findByOfferTypeAndDeletedFalse(Product.OfferType offerType, Pageable pageable);
    
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    void deleteByDeletedTrue();

    // Legacy support for older code
    default List<Product> findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(String name, String partNumber) {
        return searchProducts(name); // Assuming name is the query
    }

    @Query("SELECT p.id, p.name, SUM(oi.quantity) as total " +
           "FROM OrderItem oi JOIN oi.product p " +
           "GROUP BY p.id, p.name ORDER BY total DESC")
    List<Object[]> getTopSellingProducts();
}
