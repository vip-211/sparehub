package com.spareparts.inventory.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class SuggestionDto {
    private String name;
    private String partNumber;
    private BigDecimal price;
    private Integer stock;
}
