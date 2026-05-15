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
    
    @Query("SELECT p FROM Purchase p WHERE " +
           "LOWER(p.supplierName) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(p.invoiceNumber) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(p.productName) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(p.partNumber) LIKE LOWER(CONCAT('%', :query, '%'))")
    List<Purchase> searchPurchases(String query);
    
    boolean existsByInvoiceNumber(String invoiceNumber);
}
