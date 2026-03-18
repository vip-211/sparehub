package com.spareparts.inventory.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CategorySimpleDto {
    private Long id;
    private String name;
    private String description;
    private String imagePath;
    private String imageLink;
    private Long parentId;
    private ParentCategoryDto parent;
    private List<CategorySimpleDto> subCategories;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ParentCategoryDto {
        private Long id;
        private String name;
    }
}
