
package com.spareparts.inventory.dto;

import com.spareparts.inventory.entity.Order;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class OrderDto {
    private Long id;
    private Long customerId;
    private String customerName;
    private String customerPhone;
    private String customerAddress;
    private Long sellerId;
    private String sellerName;
    private Long deliveredById;
    private String deliveredByName;
    private BigDecimal totalAmount;
    private Order.OrderStatus status;
    private List<OrderItemDto> items;
    private Long pointsRedeemed;
    private Long pointsEarned;
    private BigDecimal discountAmount;
    private LocalDateTime createdAt;
}
