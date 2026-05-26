package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(name = "purchase_items")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PurchaseItem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "purchase_id", nullable = false)
    private Purchase purchase;

    @NotBlank
    @Column(name = "product_name")
    private String productName;

    @Column(name = "part_number")
    private String partNumber;

    @NotNull
    private Integer quantity;

    @NotNull
    @Column(name = "cost_price", precision = 10, scale = 2)
    private BigDecimal costPrice;

    @Column(name = "selling_price", precision = 10, scale = 2)
    private BigDecimal sellingPrice;

    @Column(name = "gst", precision = 10, scale = 2)
    private BigDecimal gst;

    @NotNull
    @Column(name = "total_amount", precision = 10, scale = 2)
    private BigDecimal totalAmount;
}
