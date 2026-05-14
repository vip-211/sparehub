package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "banners")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Banner {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(length = 500)
    private String imagePath;

    @Column(length = 500)
    private String imageLink;

    @Column(length = 500)
    private String targetUrl;

    @Column(name = "banner_text")
    private String text;

    @Column(name = "display_order")
    @ColumnDefault("0")
    private Integer displayOrder = 0;

    @Column(name = "is_active", nullable = false)
    @ColumnDefault("true")
    private boolean active = true;

    @Column(name = "size", length = 20)
    @ColumnDefault("'medium'")
    private String size = "medium"; // small, medium, large

    @Column(name = "is_buy_enabled", nullable = false)
    @ColumnDefault("false")
    private boolean buyEnabled = false;

    @Column(name = "product_id")
    private Long productId;

    @Column(name = "minimum_quantity")
    @ColumnDefault("1")
    private Integer minimumQuantity = 1;

    @Column(name = "is_quantity_locked", nullable = false)
    @ColumnDefault("false")
    private boolean quantityLocked = false;

    @Column(name = "fixed_price")
    private Double fixedPrice;

    @Column(name = "button_text", length = 50)
    @ColumnDefault("'Buy Now'")
    private String buttonText = "Buy Now";

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
