package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Purchase;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface PurchaseRepository extends JpaRepository<Purchase, Long> {
    List<Purchase> findByPurchaseDateBetween(LocalDate startDate, LocalDate endDate);
    List<Purchase> findByPurchaseDate(LocalDate date);
    
    @Query("SELECT DISTINCT p FROM Purchase p LEFT JOIN p.items i WHERE " +
           "LOWER(p.supplierName) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(p.invoiceNumber) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(i.productName) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(i.partNumber) LIKE LOWER(CONCAT('%', :query, '%'))")
    List<Purchase> searchPurchases(String query);
    
    boolean existsByInvoiceNumber(String invoiceNumber);
}
