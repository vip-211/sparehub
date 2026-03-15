
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
            if (category != null) {
                for (Product p : products) {
                    p.setCategory(category);
                }
            }
            productRepository.saveAll(products);
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
