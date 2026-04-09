package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
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

    @Column(name = "display_order", columnDefinition = "integer default 0")
    private Integer displayOrder = 0;

    @Column(name = "is_active", columnDefinition = "boolean default true")
    private boolean active = true;

    @Column(name = "size", length = 20, columnDefinition = "varchar(20) default 'medium'")
    private String size = "medium"; // small, medium, large

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
