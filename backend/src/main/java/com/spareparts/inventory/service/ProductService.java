
package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.PaginatedResponse;
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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProductService extends ProductSubject {
    private static final Logger log = LoggerFactory.getLogger(ProductService.class);

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

    private <T> PaginatedResponse<ProductDto> convertToPaginatedResponse(Page<Product> page) {
        List<ProductDto> content = page.getContent().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
        
        return new PaginatedResponse<>(
                content,
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages(),
                page.isLast()
        );
    }

    @Transactional(readOnly = true)
    public PaginatedResponse<ProductDto> getAllProducts(int page, int size, String sortBy, String direction) {
        Sort sort = direction.equalsIgnoreCase(Sort.Direction.ASC.name()) ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<Product> productPage = productRepository.findByDeletedFalse(pageable);
        return convertToPaginatedResponse(productPage);
    }

    @Transactional(readOnly = true)
    public PaginatedResponse<ProductDto> getProductsByCategory(Long categoryId, int page, int size, String sortBy, String direction) {
        Sort sort = direction.equalsIgnoreCase(Sort.Direction.ASC.name()) ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<Product> productPage = productRepository.findByCategory_IdAndDeletedFalse(categoryId, pageable);
        return convertToPaginatedResponse(productPage);
    }

    @Transactional(readOnly = true)
    public PaginatedResponse<ProductDto> searchProducts(String query, int page, int size, String sortBy, String direction) {
        Sort sort = direction.equalsIgnoreCase(Sort.Direction.ASC.name()) ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<Product> productPage = productRepository.searchProducts(query, pageable);
        return convertToPaginatedResponse(productPage);
    }

    @Transactional(readOnly = true)
    public PaginatedResponse<ProductDto> searchProducts(String query, int page, int size) {
        return searchProducts(query, page, size, "id", "desc");
    }

    @Transactional(readOnly = true)
    public PaginatedResponse<ProductDto> getWholesalerProducts(Long wholesalerId, int page, int size, String sortBy, String direction) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));
        Sort sort = direction.equalsIgnoreCase(Sort.Direction.ASC.name()) ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<Product> productPage = productRepository.findByWholesalerAndDeletedFalse(wholesaler, pageable);
        return convertToPaginatedResponse(productPage);
    }

    @Transactional
    public ProductDto addProduct(ProductDto productDto, Long wholesalerId) {
        User wholesaler = userRepository.findById(wholesalerId)
                .orElseThrow(() -> new RuntimeException("Wholesaler not found"));

        // Check for duplicate part number
        productRepository.findByPartNumberAndDeletedFalse(productDto.getPartNumber()).ifPresent(p -> {
            throw new RuntimeException("Product with part number " + productDto.getPartNumber() + " already exists.");
        });

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
        product.setOfferMinQty(productDto.getOfferMinQty());
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

        List<Product> products = productDtos.stream()
            .filter(dto -> {
                // Filter out products that already exist with the same part number
                boolean exists = productRepository.findByPartNumberAndDeletedFalse(dto.getPartNumber()).isPresent();
                if (exists) {
                    log.warn("Skipping duplicate product in bulk upload. Part Number: {}", dto.getPartNumber());
                }
                return !exists;
            })
            .map(dto -> {
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
            })
            .collect(Collectors.toList());
        
        if (!products.isEmpty()) {
            productRepository.saveAll(products);
            
            // Notify observers for each new product in bulk addition
            for (Product product : products) {
                notifyObservers(product);
            }
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
        product.setDescription(productDto.getDescription());
        
        if (productDto.getOfferType() != null) {
            product.setOfferType(Product.OfferType.valueOf(productDto.getOfferType()));
        }
        if (productDto.getOfferMinQty() != null) {
            product.setOfferMinQty(productDto.getOfferMinQty());
        }

        if (productDto.getCategoryId() != null) {
            categoryRepository.findById(productDto.getCategoryId()).ifPresent(product::setCategory);
        } else {
            product.setCategory(null);
        }
        product = productRepository.save(product);
        return convertToDto(product);
    }

    @Transactional(readOnly = true)
    public PaginatedResponse<ProductDto> getProductsByOfferType(String offerType, int page, int size, String sortBy, String direction) {
        Product.OfferType type = Product.OfferType.valueOf(offerType.toUpperCase());
        Sort sort = direction.equalsIgnoreCase(Sort.Direction.ASC.name()) ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<Product> productPage = productRepository.findByOfferTypeAndDeletedFalse(type, pageable);
        return convertToPaginatedResponse(productPage);
    }

    @Transactional
    public void setProductOffer(Long productId, String offerType, boolean notifyWhatsApp, boolean notifyInApp, Integer minQty) {
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new RuntimeException("Product not found"));
        
        Product.OfferType type = Product.OfferType.valueOf(offerType.toUpperCase());
        product.setOfferType(type);
        product.setOfferMinQty(minQty);
        productRepository.save(product);

        if (type != Product.OfferType.NONE) {
            if (notifyInApp) {
                inAppNotificationObserver.sendOfferNotification(product);
            }
            if (notifyWhatsApp) {
                whatsAppNotificationObserver.sendOfferNotification(product);
            }
        }
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

    @Transactional
    public void emptyRecycleBin() {
        productRepository.deleteByDeletedTrue();
    }

    @Transactional(readOnly = true)
    public List<Object[]> getTopSellingProducts() {
        return productRepository.getTopSellingProducts();
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
        dto.setOfferType(product.getOfferType() != null ? product.getOfferType().name() : null);
        dto.setOfferMinQty(product.getOfferMinQty());
        if (product.getCategory() != null) {
            dto.setCategoryId(product.getCategory().getId());
            dto.setCategoryName(product.getCategory().getName());
            dto.setCategoryImagePath(product.getCategory().getImagePath());
            dto.setCategoryImageLink(product.getCategory().getImageLink());
        }
        return dto;
    }
}
