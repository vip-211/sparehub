package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.CategorySimpleDto;
import com.spareparts.inventory.entity.Category;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.CategoryRepository;
import com.spareparts.inventory.repository.ProductRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/categories")
public class CategoryController {
    private static final Logger log = LoggerFactory.getLogger(CategoryController.class);
    @Autowired
    private CategoryRepository categoryRepository;
    @Autowired
    private ProductRepository productRepository;

    private CategorySimpleDto convertToDto(Category c) {
        if (c == null) return null;
        CategorySimpleDto dto = new CategorySimpleDto();
        dto.setId(c.getId());
        dto.setName(c.getName());
        dto.setDescription(c.getDescription());
        dto.setImagePath(c.getImagePath());
        dto.setImageLink(c.getImageLink());
        dto.setDisplayOrder(c.getDisplayOrder());
        dto.setIconCodePoint(c.getIconCodePoint());
        dto.setShowOnHome(c.getShowOnHome());
        return dto;
    }

    @GetMapping
    public ResponseEntity<?> list() {
        try {
            List<Category> categories = categoryRepository.findByDeletedFalse();
            return ResponseEntity.ok(categories.stream().map(this::convertToDto).collect(Collectors.toList()));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("Failed to list categories: " + e.getMessage());
        }
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> create(@RequestBody Map<String, Object> req) {
        try {
            System.out.println("Category creation request: " + req);
            String name = (String) req.get("name");
            String description = (String) req.get("description");
            
            if (name == null || name.trim().isEmpty()) {
                System.err.println("Category name is missing or empty");
                return ResponseEntity.badRequest().body("Category name is required");
            }
            
            Category c = new Category();
            c.setName(name);
            c.setDescription(description);
            c.setImagePath((String) req.get("imagePath"));
            c.setImageLink((String) req.get("imageLink"));
            if (req.containsKey("displayOrder")) c.setDisplayOrder((Integer) req.get("displayOrder"));
            if (req.containsKey("iconCodePoint")) c.setIconCodePoint((Integer) req.get("iconCodePoint"));
            if (req.containsKey("showOnHome")) {
                Object show = req.get("showOnHome");
                if (show instanceof Boolean) c.setShowOnHome((Boolean) show ? 1 : 0);
                else if (show instanceof Integer) c.setShowOnHome((Integer) show);
            }

            Category saved = categoryRepository.save(c);
            System.out.println("Category saved successfully: " + saved.getId());
            return ResponseEntity.ok(convertToDto(saved));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("Failed to create category: " + e.getMessage());
        }
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody Map<String, Object> req) {
        try {
            Category c = categoryRepository.findById(id).orElse(null);
            if (c == null) return ResponseEntity.notFound().build();
            
            if (req.containsKey("name")) c.setName((String) req.get("name"));
            if (req.containsKey("description")) c.setDescription((String) req.get("description"));
            if (req.containsKey("imagePath")) c.setImagePath((String) req.get("imagePath"));
            if (req.containsKey("imageLink")) c.setImageLink((String) req.get("imageLink"));
            if (req.containsKey("displayOrder")) c.setDisplayOrder((Integer) req.get("displayOrder"));
            if (req.containsKey("iconCodePoint")) c.setIconCodePoint((Integer) req.get("iconCodePoint"));
            if (req.containsKey("showOnHome")) {
                Object show = req.get("showOnHome");
                if (show instanceof Boolean) c.setShowOnHome((Boolean) show ? 1 : 0);
                else if (show instanceof Integer) c.setShowOnHome((Integer) show);
            }
            
            return ResponseEntity.ok(convertToDto(categoryRepository.save(c)));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("Failed to update category: " + e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        try {
            if (!categoryRepository.existsById(id)) return ResponseEntity.notFound().build();
            categoryRepository.deleteById(id);
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("Failed to delete category: " + e.getMessage());
        }
    }

    @Autowired
    private com.spareparts.inventory.service.ProductService productService;

    @GetMapping("/{id}/products")
    public ResponseEntity<List<ProductDto>> productsByCategory(@PathVariable Long id) {
        return ResponseEntity.ok(productService.getProductsByCategory(id));
    }
}
