package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.Offer;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.OfferRepository;
import com.spareparts.inventory.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/offers")
public class OfferController {

    @Autowired
    private OfferRepository offerRepository;

    @Autowired
    private ProductRepository productRepository;

    @GetMapping
    public ResponseEntity<List<Offer>> getAllOffers() {
        return ResponseEntity.ok(offerRepository.findAll());
    }

    @GetMapping("/active")
    public ResponseEntity<List<Offer>> getActiveOffers() {
        return ResponseEntity.ok(offerRepository.findActiveOffers());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> createOffer(@RequestBody Map<String, Object> req) {
        Long productId = Long.valueOf(req.get("productId").toString());
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new RuntimeException("Product not found"));

        Offer offer = new Offer();
        offer.setProduct(product);
        if (req.containsKey("offerPrice")) offer.setOfferPrice(new java.math.BigDecimal(req.get("offerPrice").toString()));
        offer.setMinimumQuantity(Integer.parseInt(req.get("minimumQuantity").toString()));
        offer.setQuantityLocked((Boolean) req.getOrDefault("isQuantityLocked", false));
        offer.setActive((Boolean) req.getOrDefault("isActive", true));
        offer.setDescription((String) req.get("description"));

        return ResponseEntity.ok(offerRepository.save(offer));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> updateOffer(@PathVariable Long id, @RequestBody Map<String, Object> req) {
        Offer offer = offerRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Offer not found"));

        if (req.containsKey("productId")) {
            Long productId = Long.valueOf(req.get("productId").toString());
            Product product = productRepository.findById(productId)
                    .orElseThrow(() -> new RuntimeException("Product not found"));
            offer.setProduct(product);
        }

        if (req.containsKey("offerPrice")) offer.setOfferPrice(new java.math.BigDecimal(req.get("offerPrice").toString()));
        if (req.containsKey("minimumQuantity")) offer.setMinimumQuantity(Integer.parseInt(req.get("minimumQuantity").toString()));
        if (req.containsKey("isQuantityLocked")) offer.setQuantityLocked((Boolean) req.get("isQuantityLocked"));
        if (req.containsKey("isActive")) offer.setActive((Boolean) req.get("isActive"));
        if (req.containsKey("description")) offer.setDescription((String) req.get("description"));

        return ResponseEntity.ok(offerRepository.save(offer));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<Void> deleteOffer(@PathVariable Long id) {
        offerRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
