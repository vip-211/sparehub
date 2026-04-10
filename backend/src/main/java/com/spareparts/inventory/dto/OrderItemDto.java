
package com.spareparts.inventory.dto;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class OrderItemDto {
    private Long productId;
    private String productName;
    private Integer quantity;
    private BigDecimal price;
    private Long bannerId;
    private Long offerId;
}
