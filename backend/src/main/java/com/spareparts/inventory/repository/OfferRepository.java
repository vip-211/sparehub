package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Offer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OfferRepository extends JpaRepository<Offer, Long> {
    
    @Query("SELECT o FROM Offer o WHERE o.active = true AND o.product.stock > 0")
    List<Offer> findActiveOffers();
}
