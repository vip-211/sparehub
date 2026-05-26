package com.spareparts.inventory.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PurchaseItemDto {
    private Long id;
    private String productName;
    private String partNumber;
    private Integer quantity;
    private BigDecimal costPrice;
    private BigDecimal sellingPrice;
    private BigDecimal gst;
    private BigDecimal totalAmount;
}
