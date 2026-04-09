package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "dashboard_configs")
@Data
public class DashboardConfig {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String sectionType; // BANNER, CATEGORY_GRID, FEATURED_LIST, SEARCH_BAR
    private String title;
    private String contentJson; // JSON string for flexibility (list of image URLs, category IDs, etc.)
    private Integer displayOrder;
    private boolean enabled = true;
    private String targetRole = "ROLE_MECHANIC";
}
