
package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "products")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Product {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wholesaler_id", nullable = false)
    private User wholesaler;

    @NotBlank
    @Size(max = 255)
    private String name;

    @NotBlank
    @Size(max = 100)
    @Column(unique = true)
    private String partNumber;

    @Size(max = 50)
    private String rackNumber;

    @NotNull
    @Column(columnDefinition = "numeric(38,2) default 0.0")
    private BigDecimal mrp = BigDecimal.ZERO;

    @NotNull
    @Column(columnDefinition = "numeric(38,2) default 0.0")
    private BigDecimal sellingPrice = BigDecimal.ZERO;

    @NotNull
    @Column(columnDefinition = "numeric(38,2) default 0.0")
    private BigDecimal wholesalerPrice = BigDecimal.ZERO;

    @NotNull
    @Column(columnDefinition = "numeric(38,2) default 0.0")
    private BigDecimal retailerPrice = BigDecimal.ZERO;

    @NotNull
    @Column(columnDefinition = "numeric(38,2) default 0.0")
    private BigDecimal mechanicPrice = BigDecimal.ZERO;

    @NotNull
    @Column(columnDefinition = "integer default 0")
    private Integer stock = 0;

    @NotNull
    @Column(columnDefinition = "boolean default true")
    private boolean enabled = true;

    @Size(max = 500)
    private String imagePath;

    @Column(columnDefinition = "TEXT")
    private String description;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    private Category category;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "deleted", nullable = false, columnDefinition = "boolean default false")
    private boolean deleted = false;
}
