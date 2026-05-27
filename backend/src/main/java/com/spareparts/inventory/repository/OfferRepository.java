package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Offer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OfferRepository extends JpaRepository<Offer, Long> {
    
    @Query("SELECT o FROM Offer o WHERE o.active = true AND o.product.stock > 0")
    List<Offer> findActiveOffers();
    
    @Query("SELECT o FROM Offer o WHERE o.product.id = :productId AND o.active = true AND o.product.stock > 0")
    Optional<Offer> findActiveOfferByProductId(Long productId);
}
