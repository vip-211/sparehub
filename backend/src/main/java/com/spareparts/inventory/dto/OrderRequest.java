
package com.spareparts.inventory.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class OrderRequest {
    @NotNull
    private Long sellerId;

    private Long pointsToRedeem;
    
    private Double deliveryCharge;
    
    @NotEmpty
    private List<OrderItemDto> items;
}
