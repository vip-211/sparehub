package com.spareparts.inventory.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PurchaseDto {
    private Long id;
    private String supplierName;
    private String supplierMobile;
    private String invoiceNumber;
    private LocalDate purchaseDate;
    private java.util.List<PurchaseItemDto> items;
    private BigDecimal discount;
    private BigDecimal totalAmount;
    private String notes;
    private String billImageUrl;
    private String billPdfUrl;
    private BigDecimal dailyAmount;
    private BigDecimal remainingAmount;
    private Long createdById;
    private String createdByName;
    private LocalDateTime createdAt;
}
