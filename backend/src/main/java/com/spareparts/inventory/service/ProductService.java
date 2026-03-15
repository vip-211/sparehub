
package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.Category;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.repository.CategoryRepository;
import com.spareparts.inventory.observer.InAppNotificationObserver;
import com.spareparts.inventory.observer.ProductSubject;
import com.spareparts.inventory.observer.WhatsAppNotificationObserver;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProductService extends ProductSubject {
    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private InAppNotificationObserver inAppNotificationObserver;

    @Autowired
    private WhatsAppNotificationObserver whatsAppNotificationObserver;

    @PostConstruct
    public void init() {
        addObserver(inAppNotificationObserver);
        addObserver(whatsAppNotificationObserver);
    }

    @Transactional
    public ProductDto addProduct(ProductDto productDto, Long wholesalerId) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));

        Product product = new Product();
        product.setName(productDto.getName());
        product.setPartNumber(productDto.getPartNumber());
        product.setRackNumber(productDto.getRackNumber());
        product.setMrp(productDto.getMrp());
        product.setSellingPrice(productDto.getSellingPrice());
        product.setWholesalerPrice(productDto.getWholesalerPrice());
        product.setRetailerPrice(productDto.getRetailerPrice());
        product.setMechanicPrice(productDto.getMechanicPrice());
        product.setStock(productDto.getStock());
        product.setEnabled(productDto.isEnabled());
        product.setImagePath(productDto.getImagePath());
        product.setImageLink(productDto.getImageLink());
        product.setDescription(productDto.getDescription());
        product.setWholesaler(wholesaler);
        
        // Auto-categorization logic
        Long categoryId = productDto.getCategoryId();
        if (categoryId == null) {
            categoryId = findBestCategoryMatch(productDto.getName(), productDto.getPartNumber());
        }

        if (categoryId != null) {
            categoryRepository.findById(categoryId).ifPresent(product::setCategory);
        }

        product = productRepository.save(product);
        
        // Notify observers about the new product
        notifyObservers(product);
        
        return convertToDto(product);
    }

    private Long findBestCategoryMatch(String name, String partNumber) {
        List<Category> allCategories = categoryRepository.findAll();
        return findBestCategoryMatchInList(name, partNumber, allCategories);
    }

    private Long findBestCategoryMatchInList(String name, String partNumber, List<Category> allCategories) {
        if (allCategories == null || allCategories.isEmpty()) return null;
        
        String searchStr = (name + " " + partNumber).toLowerCase();
        
        // 1. Try exact match first
        for (Category cat : allCategories) {
            String catName = cat.getName().toLowerCase();
            if (searchStr.equals(catName)) return cat.getId();
        }
        
        // 2. Try word-based matching
        String[] keywords = searchStr.split("\\s+");
        for (Category cat : allCategories) {
            String catName = cat.getName().toLowerCase();
            for (String kw : keywords) {
                if (kw.length() > 2 && catName.contains(kw)) {
                    return cat.getId();
                }
            }
        }
        
        // 3. Fallback to substring matching
        for (Category cat : allCategories) {
            String catName = cat.getName().toLowerCase();
            if (searchStr.contains(catName) || catName.contains(name.toLowerCase())) {
                return cat.getId();
            }
        }
        return null;
    }

    @Transactional(readOnly = true)
    public List<ProductDto> getWholesalerProducts(Long wholesalerId) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));
        return productRepository.findByWholesalerAndDeletedFalse(wholesaler).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ProductDto> getAllProducts() {
        return productRepository.findByDeletedFalse().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ProductDto> getDeletedProducts() {
        return productRepository.findByDeletedTrue().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ProductDto> searchProducts(String query) {
        return productRepository.searchProducts(query).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ProductDto> getProductsByCategory(Long categoryId) {
        return productRepository.findByCategory_IdAndDeletedFalse(categoryId).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public void addProductsBulk(List<ProductDto> productDtos, Long wholesalerId) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));
        
        List<Category> allCategories = categoryRepository.findAll();

        List<Product> products = productDtos.stream().map(dto -> {
            Product product = new Product();
            product.setName(dto.getName());
            product.setPartNumber(dto.getPartNumber());
            product.setRackNumber(dto.getRackNumber());
            product.setMrp(dto.getMrp());
            product.setSellingPrice(dto.getSellingPrice());
            product.setWholesalerPrice(dto.getWholesalerPrice());
            product.setRetailerPrice(dto.getRetailerPrice());
            product.setMechanicPrice(dto.getMechanicPrice());
            product.setStock(dto.getStock());
            product.setEnabled(dto.isEnabled());
            product.setImagePath(dto.getImagePath());
            product.setImageLink(dto.getImageLink());
            product.setWholesaler(wholesaler);

            Long categoryId = dto.getCategoryId();
            if (categoryId == null) {
                categoryId = findBestCategoryMatchInList(dto.getName(), dto.getPartNumber(), allCategories);
            }
            if (categoryId != null) {
                final Long finalCid = categoryId;
                allCategories.stream().filter(c -> c.getId().equals(finalCid)).findFirst().ifPresent(product::setCategory);
            }

            return product;
        }).collect(Collectors.toList());
        
        productRepository.saveAll(products);
        
        // Notify observers for each new product in bulk addition
        for (Product product : products) {
            notifyObservers(product);
        }
    }

    @Transactional
    public ProductDto updateProduct(Long id, ProductDto productDto) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found"));
        product.setName(productDto.getName());
        product.setPartNumber(productDto.getPartNumber());
        product.setRackNumber(productDto.getRackNumber());
        product.setMrp(productDto.getMrp());
        product.setSellingPrice(productDto.getSellingPrice());
        product.setWholesalerPrice(productDto.getWholesalerPrice());
        product.setRetailerPrice(productDto.getRetailerPrice());
        product.setMechanicPrice(productDto.getMechanicPrice());
        product.setStock(productDto.getStock());
        product.setEnabled(productDto.isEnabled());
        product.setImagePath(productDto.getImagePath());
        product.setImageLink(productDto.getImageLink());
        if (productDto.getCategoryId() != null) {
            categoryRepository.findById(productDto.getCategoryId()).ifPresent(product::setCategory);
        } else {
            product.setCategory(null);
        }
        product = productRepository.save(product);
        return convertToDto(product);
    }

    @Transactional
    public void deleteProduct(Long id) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found"));
        product.setDeleted(true);
        productRepository.save(product);
    }

    @Transactional
    public void restoreProduct(Long id) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found"));
        product.setDeleted(false);
        productRepository.save(product);
    }

    @Transactional
    public void deleteProductPermanent(Long id) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found"));
        productRepository.delete(product);
    }

    @Transactional
    public void deleteProductsBulk(List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return;
        }
        List<Product> products = productRepository.findAllById(ids);
        products.forEach(p -> p.setDeleted(true));
        productRepository.saveAll(products);
    }

    private ProductDto convertToDto(Product product) {
        ProductDto dto = new ProductDto();
        dto.setId(product.getId());
        dto.setName(product.getName());
        dto.setPartNumber(product.getPartNumber());
        dto.setRackNumber(product.getRackNumber());
        dto.setMrp(product.getMrp());
        dto.setSellingPrice(product.getSellingPrice());
        dto.setWholesalerPrice(product.getWholesalerPrice());
        dto.setRetailerPrice(product.getRetailerPrice());
        dto.setMechanicPrice(product.getMechanicPrice());
        dto.setStock(product.getStock());
        dto.setEnabled(product.isEnabled());
        dto.setImagePath(product.getImagePath());
        dto.setImageLink(product.getImageLink());
        dto.setDescription(product.getDescription());
        dto.setWholesalerId(product.getWholesaler().getId());
        if (product.getCategory() != null) {
            dto.setCategoryId(product.getCategory().getId());
            dto.setCategoryName(product.getCategory().getName());
            dto.setCategoryImagePath(product.getCategory().getImagePath());
            dto.setCategoryImageLink(product.getCategory().getImageLink());
        }
        return dto;
    }
}
