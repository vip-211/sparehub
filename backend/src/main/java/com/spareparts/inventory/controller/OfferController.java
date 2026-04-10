package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.Offer;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.ProductImage;
import com.spareparts.inventory.dto.OfferDto;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.repository.OfferRepository;
import com.spareparts.inventory.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.CacheEvict;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/offers")
public class OfferController {

    @Autowired
    private OfferRepository offerRepository;

    @Autowired
    private ProductRepository productRepository;

    @GetMapping
    @Transactional(readOnly = true)
    @Cacheable(cacheNames = "home_offers_all")
    public ResponseEntity<List<OfferDto>> getAllOffers() {
        List<Offer> offers = offerRepository.findAll();
        return ResponseEntity.ok(
                offers.stream().map(this::toDto).collect(Collectors.toList())
        );
    }

    @GetMapping("/active")
    @Transactional(readOnly = true)
    @Cacheable(cacheNames = "home_offers_active")
    public ResponseEntity<List<OfferDto>> getActiveOffers() {
        List<Offer> offers = offerRepository.findActiveOffers();
        return ResponseEntity.ok(
                offers.stream().map(this::toDto).collect(Collectors.toList())
        );
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_offers_all","home_offers_active"}, allEntries = true)
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
    @CacheEvict(cacheNames = {"home_offers_all","home_offers_active"}, allEntries = true)
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
    @CacheEvict(cacheNames = {"home_offers_all","home_offers_active"}, allEntries = true)
    public ResponseEntity<Void> deleteOffer(@PathVariable Long id) {
        offerRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    private OfferDto toDto(Offer offer) {
        OfferDto dto = new OfferDto();
        dto.setId(offer.getId());
        dto.setOfferPrice(offer.getOfferPrice());
        dto.setMinimumQuantity(offer.getMinimumQuantity());
        dto.setQuantityLocked(offer.isQuantityLocked());
        dto.setActive(offer.isActive());
        dto.setDescription(offer.getDescription());
        dto.setCreatedAt(offer.getCreatedAt());
        dto.setProduct(toProductDto(offer.getProduct()));
        return dto;
    }

    private ProductDto toProductDto(Product product) {
        ProductDto dto = new ProductDto();
        dto.setId(product.getId());
        dto.setName(product.getName());
        dto.setPartNumber(product.getPartNumber());
        dto.setRackNumber(product.getRackNumber());
        dto.setMrp(product.getMrp());
        dto.setSellingPrice(product.getSellingPrice());
        dto.setWholesalerPrice(product.getWholesalerPrice());
        dto.setRetailerPrice(product.getRetailerPrice());
        dto.setMechanicPrice(product.getMechanicPrice());
        dto.setStock(product.getStock());
        dto.setEnabled(product.isEnabled());
        dto.setImagePath(product.getImagePath());
        dto.setImageLink(product.getImageLink());
        dto.setImageUrls(product.getImages() != null ?
                product.getImages().stream().map(ProductImage::getImageUrl).collect(Collectors.toList()) :
                new java.util.ArrayList<>());
        dto.setMinOrderQty(product.getMinOrderQty());
        dto.setFeatured(product.isFeatured());
        dto.setDescription(product.getDescription());
        if (product.getWholesaler() != null) {
            dto.setWholesalerId(product.getWholesaler().getId());
        }
        if (product.getCategory() != null) {
            dto.setCategoryId(product.getCategory().getId());
            dto.setCategoryName(product.getCategory().getName());
            dto.setCategoryImagePath(product.getCategory().getImagePath());
            dto.setCategoryImageLink(product.getCategory().getImageLink());
        }
        dto.setOfferType(product.getOfferType() != null ? product.getOfferType().name() : null);
        dto.setOfferMinQty(product.getOfferMinQty());
        return dto;
    }
}
