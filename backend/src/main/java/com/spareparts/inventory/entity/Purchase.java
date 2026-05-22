package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "purchases")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Purchase {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(name = "supplier_name")
    private String supplierName;

    @Column(name = "supplier_mobile")
    private String supplierMobile;

    @NotBlank
    @Column(name = "invoice_number")
    private String invoiceNumber;

    @NotNull
    @Column(name = "purchase_date")
    private LocalDate purchaseDate;

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

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "bill_image_url")
    private String billImageUrl;

    @Column(name = "bill_pdf_url")
    private String billPdfUrl;

    @Column(name = "daily_amount", precision = 10, scale = 2)
    private BigDecimal dailyAmount;

    @Column(name = "remaining_amount", precision = 10, scale = 2)
    private BigDecimal remainingAmount;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_id")
    private User createdBy;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
