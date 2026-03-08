
package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProductService {
    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private UserRepository userRepository;

    @Transactional
    public ProductDto addProduct(ProductDto productDto, Long wholesalerId) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));

        Product product = new Product();
        product.setName(productDto.getName());
        product.setPartNumber(productDto.getPartNumber());
        product.setMrp(productDto.getMrp());
        product.setSellingPrice(productDto.getSellingPrice());
        product.setWholesalerPrice(productDto.getWholesalerPrice());
        product.setRetailerPrice(productDto.getRetailerPrice());
        product.setMechanicPrice(productDto.getMechanicPrice());
        product.setStock(productDto.getStock());
        product.setImagePath(productDto.getImagePath());
        product.setWholesaler(wholesaler);

        product = productRepository.save(product);
        return convertToDto(product);
    }

    @Transactional(readOnly = true)
    public List<ProductDto> getWholesalerProducts(Long wholesalerId) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));
        return productRepository.findByWholesaler(wholesaler).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ProductDto> getAllProducts() {
        return productRepository.findAll().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ProductDto> searchProducts(String query) {
        return productRepository.findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(query, query).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public void addProductsBulk(List<ProductDto> productDtos, Long wholesalerId) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));
        
        List<Product> products = productDtos.stream().map(dto -> {
            Product product = new Product();
            product.setName(dto.getName());
            product.setPartNumber(dto.getPartNumber());
            product.setMrp(dto.getMrp());
            product.setSellingPrice(dto.getSellingPrice());
            product.setWholesalerPrice(dto.getWholesalerPrice());
            product.setRetailerPrice(dto.getRetailerPrice());
            product.setMechanicPrice(dto.getMechanicPrice());
            product.setStock(dto.getStock());
            product.setImagePath(dto.getImagePath());
            product.setWholesaler(wholesaler);
            return product;
        }).collect(Collectors.toList());
        
        productRepository.saveAll(products);
    }

    @Transactional
    public ProductDto updateProduct(Long id, ProductDto productDto) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found"));
        product.setName(productDto.getName());
        product.setPartNumber(productDto.getPartNumber());
        product.setMrp(productDto.getMrp());
        product.setSellingPrice(productDto.getSellingPrice());
        product.setWholesalerPrice(productDto.getWholesalerPrice());
        product.setRetailerPrice(productDto.getRetailerPrice());
        product.setMechanicPrice(productDto.getMechanicPrice());
        product.setStock(productDto.getStock());
        product.setImagePath(productDto.getImagePath());
        product = productRepository.save(product);
        return convertToDto(product);
    }

    @Transactional
    public void deleteProduct(Long id) {
        if (!productRepository.existsById(id)) {
            throw new RuntimeException("Product not found");
        }
        productRepository.deleteById(id);
    }

    @Transactional
    public void deleteProductsBulk(List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return;
        }
        productRepository.deleteAllByIdInBatch(ids);
    }

    private ProductDto convertToDto(Product product) {
        ProductDto dto = new ProductDto();
        dto.setId(product.getId());
        dto.setName(product.getName());
        dto.setPartNumber(product.getPartNumber());
        dto.setMrp(product.getMrp());
        dto.setSellingPrice(product.getSellingPrice());
        dto.setWholesalerPrice(product.getWholesalerPrice());
        dto.setRetailerPrice(product.getRetailerPrice());
        dto.setMechanicPrice(product.getMechanicPrice());
        dto.setStock(product.getStock());
        dto.setImagePath(product.getImagePath());
        dto.setWholesalerId(product.getWholesaler().getId());
        return dto;
    }
}
