package com.spareparts.inventory.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class OfferDto {
    private Long id;
    private ProductDto product;
    private BigDecimal offerPrice;
    private Integer minimumQuantity;
    private boolean quantityLocked;
    private boolean active;
    private String description;
    private LocalDateTime createdAt;
}

