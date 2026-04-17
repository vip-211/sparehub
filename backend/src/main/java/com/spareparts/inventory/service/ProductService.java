
package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.PaginatedResponse;
import com.spareparts.inventory.dto.ProductDto;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.ProductAlias;
import com.spareparts.inventory.entity.Category;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.entity.ProductImage;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.ProductAliasRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.repository.CategoryRepository;
import com.spareparts.inventory.observer.ProductObserver;
import com.spareparts.inventory.observer.ProductSubject;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
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
    private ProductAliasRepository productAliasRepository;

    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    @Qualifier("inAppNotificationObserver")
    private ProductObserver inAppNotificationObserver;

    @Autowired
    @Qualifier("whatsAppNotificationObserver")
    private ProductObserver whatsAppNotificationObserver;

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

        Product product = null;

        // Check if a product with the same part number already exists (global check since it's unique in DB)
        if (productDto.getPartNumber() != null && !productDto.getPartNumber().isEmpty()) {
            java.util.Optional<Product> existing = productRepository.findByPartNumber(productDto.getPartNumber());
            if (existing.isPresent()) {
                Product e = existing.get();
                if (!e.getWholesaler().getId().equals(wholesaler.getId())) {
                    throw new RuntimeException("Error: Product with part number " + productDto.getPartNumber() + " is already registered by another wholesaler.");
                }
                // If it belongs to same wholesaler, we should update instead of throw error
                // For simplicity in addProduct, we might still throw error if UI expects fresh add, 
                // but let's at least mention it.
                if (!e.isDeleted()) {
                    throw new RuntimeException("Error: Product with part number " + productDto.getPartNumber() + " already exists!");
                }
                // If it was deleted, we'll continue and "re-create" it by updating the deleted one
                product = e;
                product.setDeleted(false);
            }
        }

        if (product == null) {
            product = new Product();
        }
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
        
        if (productDto.getImageUrls() != null && !productDto.getImageUrls().isEmpty()) {
            java.util.List<ProductImage> productImages = new java.util.ArrayList<>();
            for (int i = 0; i < productDto.getImageUrls().size(); i++) {
                ProductImage img = new ProductImage();
                img.setImageUrl(productDto.getImageUrls().get(i));
                img.setDisplayOrder(i);
                img.setProduct(product);
                productImages.add(img);
            }
            product.setImages(productImages);
        }

        if (productDto.getMinOrderQty() != null) {
            product.setMinOrderQty(productDto.getMinOrderQty());
        } else if (product.getMinOrderQty() == null) {
            product.setMinOrderQty(1);
        }
        product.setDescription(productDto.getDescription());
        product.setOfferMinQty(productDto.getOfferMinQty());
        product.setWholesaler(wholesaler);
        product.setFeatured(productDto.isFeatured());
        
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
        java.util.Map<String, Product> processedInBatch = new java.util.HashMap<>();
        java.util.List<Product> toSave = new java.util.ArrayList<>();

        for (ProductDto dto : productDtos) {
            if (dto.getPartNumber() == null || dto.getPartNumber().trim().isEmpty()) continue;
            String partNumber = dto.getPartNumber().trim();

            Product product;
            if (processedInBatch.containsKey(partNumber)) {
                product = processedInBatch.get(partNumber);
                updateProductFromDto(product, dto, wholesaler, allCategories);
                continue;
            }

            // Check if product already exists by partNumber (global check)
            java.util.Optional<Product> existing = productRepository.findByPartNumber(partNumber);
            if (existing.isPresent()) {
                Product e = existing.get();
                if (!e.getWholesaler().getId().equals(wholesaler.getId())) {
                    log.warn("Skipping product belonging to another wholesaler: {}", partNumber);
                    continue;
                }
                product = e;
                product.setDeleted(false);
            } else {
                product = new Product();
                toSave.add(product);
            }
            
            updateProductFromDto(product, dto, wholesaler, allCategories);
            processedInBatch.put(partNumber, product);
        }
        
        if (!processedInBatch.isEmpty()) {
            productRepository.saveAll(processedInBatch.values());
            
            // Notify observers for each product in bulk addition
            for (Product product : processedInBatch.values()) {
                notifyObservers(product);
            }
        }
    }

    private void updateProductFromDto(Product product, ProductDto dto, User wholesaler, List<Category> allCategories) {
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
        
        if (dto.getImageUrls() != null && !dto.getImageUrls().isEmpty()) {
            java.util.List<ProductImage> productImages = new java.util.ArrayList<>();
            for (int i = 0; i < dto.getImageUrls().size(); i++) {
                ProductImage img = new ProductImage();
                img.setImageUrl(dto.getImageUrls().get(i));
                img.setDisplayOrder(i);
                img.setProduct(product);
                productImages.add(img);
            }
            product.setImages(productImages);
        }

        if (dto.getMinOrderQty() != null) {
            product.setMinOrderQty(dto.getMinOrderQty());
        } else {
            product.setMinOrderQty(1);
        }
        product.setWholesaler(wholesaler);
        product.setFeatured(dto.isFeatured());

        Long categoryId = dto.getCategoryId();
        if (categoryId == null) {
            categoryId = findBestCategoryMatchInList(dto.getName(), dto.getPartNumber(), allCategories);
        }
        if (categoryId != null) {
            final Long finalCid = categoryId;
            allCategories.stream().filter(c -> c.getId().equals(finalCid)).findFirst().ifPresent(product::setCategory);
        }
    }

    @Transactional
    public ProductDto updateProduct(Long id, ProductDto productDto) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Product not found"));

        // Check for duplicate part number if it's being changed
        if (productDto.getPartNumber() != null && !productDto.getPartNumber().equals(product.getPartNumber())) {
            if (productRepository.findByPartNumberAndDeletedFalse(productDto.getPartNumber()).isPresent()) {
                throw new RuntimeException("Error: Product with part number " + productDto.getPartNumber() + " already exists!");
            }
        }

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
        
        // Update images
        product.getImages().clear();
        if (productDto.getImageUrls() != null) {
            for (int i = 0; i < productDto.getImageUrls().size(); i++) {
                ProductImage img = new ProductImage();
                img.setImageUrl(productDto.getImageUrls().get(i));
                img.setDisplayOrder(i);
                img.setProduct(product);
                product.getImages().add(img);
            }
        }

        if (productDto.getMinOrderQty() != null) {
            product.setMinOrderQty(productDto.getMinOrderQty());
        }
        product.setFeatured(productDto.isFeatured());
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
    public List<ProductDto> getFeaturedProducts() {
        return productRepository.findByFeaturedTrueAndDeletedFalse().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public void updateFeaturedStatus(List<Long> productIds, boolean isFeatured) {
        if (productIds == null || productIds.isEmpty()) return;
        List<Product> products = productRepository.findAllById(productIds);
        products.forEach(p -> p.setFeatured(isFeatured));
        productRepository.saveAll(products);
    }

    @Transactional(readOnly = true)
    public List<Object[]> getTopSellingProducts() {
        return productRepository.getTopSellingProducts();
    }

    @Transactional(readOnly = true)
    public ProductDto getProductById(Long id) {
        return productRepository.findById(id)
                .map(this::convertToDto)
                .orElse(null);
    }

    @Transactional(readOnly = true)
    public List<ProductDto> getTrendingProducts() {
        // Simple logic for trending: top selling or featured or with discount
        List<Object[]> topSelling = getTopSellingProducts();
        if (!topSelling.isEmpty()) {
            List<Long> ids = topSelling.stream()
                    .limit(20)
                    .map(o -> (Long) o[0])
                    .collect(Collectors.toList());
            return productRepository.findAllById(ids).stream()
                    .map(this::convertToDto)
                    .collect(Collectors.toList());
        }
        return getFeaturedProducts();
    }

    @Transactional(readOnly = true)
    public List<java.util.Map<String, Object>> getAliases(Long productId) {
        return productAliasRepository.findByProductId(productId).stream()
                .map(a -> {
                    java.util.Map<String, Object> map = new java.util.HashMap<>();
                    map.put("id", a.getId());
                    map.put("alias", a.getAlias());
                    map.put("pronunciation", a.getPronunciation());
                    return map;
                })
                .collect(Collectors.toList());
    }

    @Transactional
    public void addAlias(Long productId, String alias, String pronunciation) {
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new RuntimeException("Product not found"));
        ProductAlias a = new ProductAlias();
        a.setProduct(product);
        a.setAlias(alias);
        a.setPronunciation(pronunciation);
        productAliasRepository.save(a);
    }

    @Transactional
    public void deleteAlias(Long id) {
        productAliasRepository.deleteById(id);
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
        dto.setImageUrls(product.getImages() != null ? 
                product.getImages().stream().map(ProductImage::getImageUrl).collect(Collectors.toList()) : 
                new java.util.ArrayList<>());
        dto.setMinOrderQty(product.getMinOrderQty());
        dto.setFeatured(product.isFeatured());
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
