
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.PaginatedResponse;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.security.UserDetailsImpl;
import com.spareparts.inventory.service.ProductService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@CrossOrigin(origins = "${app.cors.allowed-origins}", maxAge = 3600)
@RestController
@RequestMapping("/api/products")
public class ProductController {
    @Autowired
    private ProductService productService;

    @PostMapping
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<ProductDto> addProduct(@Valid @RequestBody ProductDto productDto, Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(productService.addProduct(productDto, userDetails.getId()));
    }

    @PostMapping("/bulk")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> addProductsBulk(@RequestBody List<ProductDto> productDtos, Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        productService.addProductsBulk(productDtos, userDetails.getId());
        return ResponseEntity.ok().build();
    }

    @GetMapping("/wholesaler")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<PaginatedResponse<ProductDto>> getWholesalerProducts(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction,
            Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        return ResponseEntity.ok(productService.getWholesalerProducts(userDetails.getId(), page, size, sortBy, direction));
    }

    @GetMapping
    public ResponseEntity<PaginatedResponse<ProductDto>> getAllProducts(
            @RequestParam(required = false) Long categoryId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction) {
        if (categoryId != null) {
            return ResponseEntity.ok(productService.getProductsByCategory(categoryId, page, size, sortBy, direction));
        }
        return ResponseEntity.ok(productService.getAllProducts(page, size, sortBy, direction));
    }

    @GetMapping("/search")
    public ResponseEntity<PaginatedResponse<ProductDto>> searchProducts(
            @RequestParam String query,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction) {
        return ResponseEntity.ok(productService.searchProducts(query, page, size, sortBy, direction));
    }

    @GetMapping("/offers")
    public ResponseEntity<PaginatedResponse<ProductDto>> getProductsByOfferType(
            @RequestParam String type,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String direction) {
        return ResponseEntity.ok(productService.getProductsByOfferType(type, page, size, sortBy, direction));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<ProductDto> updateProduct(@PathVariable Long id, @Valid @RequestBody ProductDto productDto, Authentication authentication) {
        return ResponseEntity.ok(productService.updateProduct(id, productDto));
    }

    @DeleteMapping("/empty-recycle-bin")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> emptyRecycleBin() {
        productService.emptyRecycleBin();
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/delete-bulk")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteProductsBulk(@RequestBody List<Long> ids) {
        productService.deleteProductsBulk(ids);
        return ResponseEntity.ok().build();
    }
}
