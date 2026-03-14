package com.spareparts.inventory.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CustomOrderRequestDto {
    private Long id;
    private Long customerId;
    private String customerName;
    private String text;
    private String photoPath;
    private String status;
    private LocalDateTime createdAt;
    private Long assignedStaffId;
    private String assignedStaffName;
}
