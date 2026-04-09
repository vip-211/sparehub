
package com.spareparts.inventory.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class ProductDto {
    private Long id;
    
    @NotBlank
    private String name;
    
    @NotBlank
    private String partNumber;
    
    private String rackNumber;
    
    @NotNull
    private BigDecimal mrp;
    
    @NotNull
    private BigDecimal sellingPrice;
    
    @NotNull
    private BigDecimal wholesalerPrice;
    
    @NotNull
    private BigDecimal retailerPrice;
    
    @NotNull
    private BigDecimal mechanicPrice;
    
    @NotNull
    private Integer stock;
    
    private boolean enabled;
    
    private String imagePath;
    private String imageLink;
    private java.util.List<String> imageLinks;
    private Integer minOrderQty;
    private boolean isFeatured;
    private String description;
    
    private Long wholesalerId;
    
    private Long categoryId;
    private String categoryName;
    private String categoryImagePath;
    private String categoryImageLink;
    
    private String offerType;
    private Integer offerMinQty;
}
