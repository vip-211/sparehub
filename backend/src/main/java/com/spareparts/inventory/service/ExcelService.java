
package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.ProductImage;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.List;
import java.util.Optional;

@Service
public class ExcelService {
    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private com.spareparts.inventory.repository.CategoryRepository categoryRepository;

    @Transactional
    public void save(MultipartFile file, Long wholesalerId, Long categoryId) {
        try {
            User wholesaler = userRepository.findById(wholesalerId)
                    .orElseThrow(() -> new RuntimeException("Wholesaler not found"));

            com.spareparts.inventory.entity.Category category = null;
            if (categoryId != null) {
                category = categoryRepository.findById(categoryId).orElse(null);
            }

            List<Product> products = ExcelHelper.excelToProducts(file.getInputStream(), wholesaler);
            java.util.Map<String, Product> processedInBatch = new java.util.HashMap<>();

            for (Product p : products) {
                if (p.getPartNumber() == null || p.getPartNumber().trim().isEmpty()) continue;
                String partNumber = p.getPartNumber().trim();

                if (category != null) {
                    p.setCategory(category);
                }

                // Check if we already processed this part number in the current batch
                if (processedInBatch.containsKey(partNumber)) {
                    Product existingInBatch = processedInBatch.get(partNumber);
                    updateProductData(existingInBatch, p, category);
                    continue;
                }

                // Check if product already exists in DB
                Optional<Product> existing = productRepository.findByPartNumber(partNumber);
                if (existing.isPresent()) {
                    Product e = existing.get();
                    
                    if (!e.getWholesaler().getId().equals(wholesaler.getId())) {
                        throw new RuntimeException("Part number '" + partNumber + "' is already registered by another wholesaler.");
                    }
                    
                    updateProductData(e, p, category);
                    e.setDeleted(false);
                    productRepository.save(e);
                    processedInBatch.put(partNumber, e);
                } else {
                    productRepository.save(p);
                    processedInBatch.put(partNumber, p);
                }
            }
        } catch (IOException e) {
            throw new RuntimeException("fail to store excel data: " + e.getMessage());
        }
    }

    private void updateProductData(Product target, Product source, com.spareparts.inventory.entity.Category category) {
        target.setName(source.getName());
        target.setMrp(source.getMrp());
        target.setSellingPrice(source.getSellingPrice());
        target.setWholesalerPrice(source.getWholesalerPrice());
        target.setRetailerPrice(source.getRetailerPrice());
        target.setMechanicPrice(source.getMechanicPrice());
        target.setStock(source.getStock());
        target.setRackNumber(source.getRackNumber());
        target.setDescription(source.getDescription());
        target.setMinOrderQty(source.getMinOrderQty());
        
        if (category != null) {
            target.setCategory(category);
        }

        // Update images
        if (source.getImages() != null) {
            target.getImages().clear();
            for (int i = 0; i < source.getImages().size(); i++) {
                ProductImage oldImg = source.getImages().get(i);
                ProductImage newImg = new ProductImage();
                newImg.setImageUrl(oldImg.getImageUrl());
                newImg.setDisplayOrder(i);
                newImg.setProduct(target);
                target.getImages().add(newImg);
            }
        }
    }

    @Transactional(readOnly = true)
    public ByteArrayInputStream load() {
        List<Product> products = productRepository.findAll();
        ByteArrayInputStream in = ExcelHelper.productsToExcel(products);
        return in;
    }
}
