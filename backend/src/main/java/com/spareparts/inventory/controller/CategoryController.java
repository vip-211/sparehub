package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.Category;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.CategoryRepository;
import com.spareparts.inventory.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/categories")
public class CategoryController {
    @Autowired
    private CategoryRepository categoryRepository;
    @Autowired
    private ProductRepository productRepository;

    @GetMapping
    public ResponseEntity<List<Category>> list() {
        return ResponseEntity.ok(categoryRepository.findAll());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<Category> create(@RequestBody Map<String, String> req) {
        String name = req.getOrDefault("name", "").trim();
        String description = req.getOrDefault("description", "").trim();
        if (name.isEmpty()) {
            return ResponseEntity.badRequest().build();
        }
        if (categoryRepository.findByNameIgnoreCase(name).isPresent()) {
            return ResponseEntity.badRequest().build();
        }
        Category c = new Category();
        c.setName(name);
        c.setDescription(description);
        return ResponseEntity.ok(categoryRepository.save(c));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<Category> update(@PathVariable Long id, @RequestBody Map<String, String> req) {
        Category c = categoryRepository.findById(id).orElse(null);
        if (c == null) return ResponseEntity.notFound().build();
        String name = req.getOrDefault("name", c.getName());
        String description = req.getOrDefault("description", c.getDescription());
        c.setName(name);
        c.setDescription(description);
        return ResponseEntity.ok(categoryRepository.save(c));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        if (!categoryRepository.existsById(id)) return ResponseEntity.notFound().build();
        categoryRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{id}/products")
    public ResponseEntity<List<ProductDto>> productsByCategory(@PathVariable Long id) {
        List<Product> products = productRepository.findByCategory_IdAndDeletedFalse(id);
        List<ProductDto> dtos = products.stream().map(p -> {
            ProductDto dto = new ProductDto();
            dto.setId(p.getId());
            dto.setName(p.getName());
            dto.setPartNumber(p.getPartNumber());
            dto.setMrp(p.getMrp());
            dto.setSellingPrice(p.getSellingPrice());
            dto.setWholesalerPrice(p.getWholesalerPrice());
            dto.setRetailerPrice(p.getRetailerPrice());
            dto.setMechanicPrice(p.getMechanicPrice());
            dto.setStock(p.getStock());
            dto.setImagePath(p.getImagePath());
            dto.setWholesalerId(p.getWholesaler().getId());
            if (p.getCategory() != null) dto.setCategoryId(p.getCategory().getId());
            return dto;
        }).collect(Collectors.toList());
        return ResponseEntity.ok(dtos);
    }
}
