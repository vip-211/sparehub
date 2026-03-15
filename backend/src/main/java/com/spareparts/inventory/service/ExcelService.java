
package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
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

    public void save(MultipartFile file, Long wholesalerId, Long categoryId) {
        try {
            User wholesaler = userRepository.findById(wholesalerId)
                    .orElseThrow(() -> new RuntimeException("Wholesaler not found"));

            com.spareparts.inventory.entity.Category category = null;
            if (categoryId != null) {
                category = categoryRepository.findById(categoryId).orElse(null);
            }

            List<Product> products = ExcelHelper.excelToProducts(file.getInputStream(), wholesaler);
            for (Product p : products) {
                if (category != null) {
                      p.setCategory(category);
                  }
                  // Check if product already exists by partNumber for this wholesaler
                  Optional<Product> existing = productRepository.findByPartNumberAndWholesalerAndDeletedFalse(p.getPartNumber(), wholesaler);
                  if (existing.isPresent()) {
                      Product e = existing.get();
                      e.setName(p.getName());
                      e.setMrp(p.getMrp());
                      e.setSellingPrice(p.getSellingPrice());
                      e.setStock(p.getStock());
                      if (category != null) e.setCategory(category);
                      productRepository.save(e);
                  } else {
                      productRepository.save(p);
                  }
            }
        } catch (IOException e) {
            throw new RuntimeException("fail to store excel data: " + e.getMessage());
        }
    }

    public ByteArrayInputStream load() {
        List<Product> products = productRepository.findAll();
        ByteArrayInputStream in = ExcelHelper.productsToExcel(products);
        return in;
    }
}
