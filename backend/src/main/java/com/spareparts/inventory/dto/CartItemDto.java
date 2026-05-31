
package com.spareparts.inventory.dto;

import lombok.Data;

@Data
public class CartItemDto {
    private Long id;
    private Long productId;
    private String name;
    private String partNumber;
    private String image;
    private Double price; // based on user role
    private Integer quantity;
    private Boolean isLocked;
    private Long bannerId;
    private Long offerId;
}

