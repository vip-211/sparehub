package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Banner;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BannerRepository extends JpaRepository<Banner, Long> {
    
    @Query("SELECT b FROM Banner b WHERE b.active = true ORDER BY b.displayOrder ASC")
    List<Banner> findActiveBanners();
}
