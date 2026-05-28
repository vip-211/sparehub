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

    @OneToMany(mappedBy = "purchase", cascade = CascadeType.ALL, orphanRemoval = true)
    private java.util.List<PurchaseItem> items = new java.util.ArrayList<>();

    @Column(name = "discount", precision = 10, scale = 2)
    private BigDecimal discount = BigDecimal.ZERO;

    @NotNull
    @Column(name = "total_amount", precision = 10, scale = 2)
    private BigDecimal totalAmount;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "bill_image_url")
    private String billImageUrl;

    @Column(name = "bill_pdf_url")
    private String billPdfUrl;

    @Column(name = "cost_price", precision = 10, scale = 2)
    private BigDecimal costPrice = BigDecimal.ZERO;

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
