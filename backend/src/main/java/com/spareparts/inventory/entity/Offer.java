package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "offers")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Offer {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(name = "offer_price")
    private BigDecimal offerPrice;

    @Column(name = "minimum_quantity", nullable = false, columnDefinition = "integer default 1")
    private Integer minimumQuantity = 1;

    @Column(name = "is_quantity_locked", columnDefinition = "boolean default false")
    private boolean quantityLocked = false;

    @Column(name = "is_active", columnDefinition = "boolean default true")
    private boolean active = true;

    @Column(name = "description")
    private String description;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
