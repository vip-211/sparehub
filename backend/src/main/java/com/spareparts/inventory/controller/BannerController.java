package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.Banner;
import com.spareparts.inventory.repository.BannerRepository;
import com.spareparts.inventory.repository.SystemSettingRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.CacheEvict;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/banners")
public class BannerController {

    @Autowired
    private BannerRepository bannerRepository;

    @Autowired
    private SystemSettingRepository systemSettingRepository;

    @GetMapping
    @Cacheable(cacheNames = "home_banners_all")
    public ResponseEntity<List<Banner>> getAllBanners() {
        return ResponseEntity.ok(bannerRepository.findAll());
    }

    @GetMapping("/active")
    @Cacheable(cacheNames = "home_banners_active")
    public ResponseEntity<Map<String, Object>> getActiveBanners() {
        List<Banner> activeBanners = bannerRepository.findActiveBanners();
        int speed = Integer.parseInt(systemSettingRepository.getSettingValue("banner_scroll_speed", "3"));
        
        return ResponseEntity.ok(Map.of(
            "isCarousel", activeBanners.size() > 1,
            "autoScrollSpeed", speed,
            "banners", activeBanners
        ));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_banners_all", "home_banners_active"}, allEntries = true)
    public ResponseEntity<Banner> createBanner(@RequestBody Banner banner) {
        return ResponseEntity.ok(bannerRepository.save(banner));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_banners_all", "home_banners_active"}, allEntries = true)
    public ResponseEntity<Banner> updateBanner(@PathVariable Long id, @RequestBody Banner bannerDetails) {
        Banner banner = bannerRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Banner not found with id: " + id));

        banner.setTitle(bannerDetails.getTitle());
        banner.setImagePath(bannerDetails.getImagePath());
        banner.setImageLink(bannerDetails.getImageLink());
        banner.setTargetUrl(bannerDetails.getTargetUrl());
        banner.setText(bannerDetails.getText());
        banner.setDisplayOrder(bannerDetails.getDisplayOrder());
        banner.setActive(bannerDetails.isActive());
        banner.setSize(bannerDetails.getSize());
        
        // Buy button fields
        banner.setBuyEnabled(bannerDetails.isBuyEnabled());
        banner.setProductId(bannerDetails.getProductId());
        banner.setMinimumQuantity(bannerDetails.getMinimumQuantity());
        banner.setQuantityLocked(bannerDetails.isQuantityLocked());
        banner.setFixedPrice(bannerDetails.getFixedPrice());
        banner.setButtonText(bannerDetails.getButtonText());

        return ResponseEntity.ok(bannerRepository.save(banner));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = {"home_banners_all", "home_banners_active"}, allEntries = true)
    public ResponseEntity<Void> deleteBanner(@PathVariable Long id) {
        bannerRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
