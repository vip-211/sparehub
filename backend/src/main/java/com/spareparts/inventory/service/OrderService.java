
package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.*;
import com.spareparts.inventory.dto.OrderRequest;
import com.spareparts.inventory.entity.*;
import com.spareparts.inventory.repository.OrderRepository;
import com.spareparts.inventory.repository.OrderRequestRepository;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class OrderService {
    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private OrderRequestRepository orderRequestRepository;

    @Transactional
    public CustomOrderRequestDto createCustomOrderRequest(String text, String photoPath, Long customerId) {
        User customer = userRepository.findById(customerId)
                .orElseThrow(() -> new RuntimeException("Customer not found: " + customerId));

        CustomOrderRequest request = new CustomOrderRequest();
        request.setCustomer(customer);
        request.setText(text);
        request.setPhotoPath(photoPath);
        request.setStatus(CustomOrderRequest.RequestStatus.NEW);
        request.setCreatedAt(LocalDateTime.now());

        request = orderRequestRepository.save(request);
        return convertToCustomRequestDto(request);
    }

    @Transactional(readOnly = true)
    public List<CustomOrderRequestDto> getAllCustomOrderRequests() {
        return orderRequestRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::convertToCustomRequestDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public CustomOrderRequestDto updateCustomOrderRequestStatus(Long requestId, String status, Long staffId) {
        CustomOrderRequest request = orderRequestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Order Request not found"));

        request.setStatus(CustomOrderRequest.RequestStatus.valueOf(status));
        if (staffId != null) {
            userRepository.findById(staffId).ifPresent(request::setAssignedStaff);
        }

        request = orderRequestRepository.save(request);
        return convertToCustomRequestDto(request);
    }

    private CustomOrderRequestDto convertToCustomRequestDto(CustomOrderRequest request) {
        CustomOrderRequestDto dto = new CustomOrderRequestDto();
        dto.setId(request.getId());
        dto.setCustomerId(request.getCustomer().getId());
        dto.setCustomerName(request.getCustomer().getName());
        dto.setText(request.getText());
        dto.setPhotoPath(request.getPhotoPath());
        dto.setStatus(request.getStatus().name());
        dto.setCreatedAt(request.getCreatedAt());
        if (request.getAssignedStaff() != null) {
            dto.setAssignedStaffId(request.getAssignedStaff().getId());
            dto.setAssignedStaffName(request.getAssignedStaff().getName());
        }
        return dto;
    }

    @Transactional
    public OrderDto createOrder(OrderRequest orderRequest, Long customerId) {
        System.out.println("Creating order for customerId: " + customerId + " and sellerId: " + orderRequest.getSellerId());
        
        User customer = userRepository.findById(customerId)
                .orElseThrow(() -> new RuntimeException("Customer not found: " + customerId));
        User seller = userRepository.findById(orderRequest.getSellerId())
                .orElseThrow(() -> new RuntimeException("Seller not found: " + orderRequest.getSellerId()));

        Order order = new Order();
        order.setCustomer(customer);
        order.setSeller(seller);
        order.setStatus(Order.OrderStatus.PENDING);

        BigDecimal totalAmount = BigDecimal.ZERO;
        for (OrderItemDto itemDto : orderRequest.getItems()) {
            System.out.println("Processing item: " + itemDto.getProductName() + " (ID: " + itemDto.getProductId() + ")");
            Product product = productRepository.findById(itemDto.getProductId())
                    .orElseThrow(() -> new RuntimeException("Product not found: " + itemDto.getProductId()));

            if (product.getStock() < itemDto.getQuantity()) {
                System.err.println("Insufficient stock for " + product.getName() + ". Available: " + product.getStock() + ", Requested: " + itemDto.getQuantity());
                throw new RuntimeException("Insufficient stock for product: " + product.getName() + " (Available: " + product.getStock() + ")");
            }

            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProduct(product);
            
            int quantity = itemDto.getQuantity() != null ? itemDto.getQuantity() : 0;
            orderItem.setQuantity(quantity);
            
            // Determine price based on customer role
            BigDecimal price = product.getSellingPrice() != null ? product.getSellingPrice() : BigDecimal.ZERO;
            if (customer.getRole() != null && customer.getRole().getName() != null) {
                if (customer.getRole().getName() == RoleName.ROLE_MECHANIC && product.getMechanicPrice() != null) {
                    price = product.getMechanicPrice();
                } else if (customer.getRole().getName() == RoleName.ROLE_RETAILER && product.getRetailerPrice() != null) {
                    price = product.getRetailerPrice();
                }
            }
            orderItem.setPrice(price);

            order.getItems().add(orderItem);
            totalAmount = totalAmount.add(price.multiply(BigDecimal.valueOf(quantity)));

            // Update product stock
            int currentStock = product.getStock() != null ? product.getStock() : 0;
            product.setStock(currentStock - quantity);
            productRepository.save(product);
        }

        order.setTotalAmount(totalAmount);
        order = orderRepository.save(order);
        System.out.println("Order created successfully with ID: " + order.getId());

        return convertToDto(order);
    }

    @Transactional
    public OrderDto createAdminOrder(AdminOrderRequest orderRequest) {
        User customer = userRepository.findById(orderRequest.getCustomerId())
                .orElseThrow(() -> new RuntimeException("Customer not found"));
        User seller = userRepository.findById(orderRequest.getSellerId())
                .orElseThrow(() -> new RuntimeException("Seller not found"));

        Order order = new Order();
        order.setCustomer(customer);
        order.setSeller(seller);
        order.setStatus(Order.OrderStatus.APPROVED);

        BigDecimal totalAmount = BigDecimal.ZERO;
        for (OrderItemDto itemDto : orderRequest.getItems()) {
            Product product = productRepository.findById(itemDto.getProductId())
                    .orElseThrow(() -> new RuntimeException("Product not found: " + itemDto.getProductId()));

            if (product.getStock() < itemDto.getQuantity()) {
                throw new RuntimeException("Insufficient stock for product: " + product.getName());
            }

            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProduct(product);
            
            int quantity = itemDto.getQuantity() != null ? itemDto.getQuantity() : 0;
            orderItem.setQuantity(quantity);
            
            BigDecimal price = itemDto.getPrice() != null ? itemDto.getPrice() : product.getSellingPrice();
            if (price == null) price = BigDecimal.ZERO;
            orderItem.setPrice(price); // Use provided price for admin orders

            order.getItems().add(orderItem);
            totalAmount = totalAmount.add(price.multiply(BigDecimal.valueOf(quantity)));

            // Update product stock
            int currentStock = product.getStock() != null ? product.getStock() : 0;
            product.setStock(currentStock - quantity);
            productRepository.save(product);
        }

        order.setTotalAmount(totalAmount);
        order = orderRepository.save(order);

        return convertToDto(order);
    }

    @Transactional(readOnly = true)
    public List<OrderDto> getCustomerOrders(Long customerId) {
        User customer = userRepository.findById(customerId)
                .orElseThrow(() -> new RuntimeException("Customer not found"));
        return orderRepository.findByCustomerAndDeletedFalse(customer).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<OrderDto> getSellerOrders(Long sellerId) {
        User seller = userRepository.findById(sellerId)
                .orElseThrow(() -> new RuntimeException("Seller not found"));
        return orderRepository.findBySellerAndDeletedFalse(seller).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<OrderDto> getAllOrders() {
        return orderRepository.findByDeletedFalse().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<OrderDto> getDeletedOrders() {
        return orderRepository.findByDeletedTrue().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public OrderDto getOrderById(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        return convertToDto(order);
    }

    @Transactional
    public OrderDto updateOrderStatus(Long orderId, Order.OrderStatus status, Long userId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        
        order.setStatus(status);
        
        // If status is OUT_FOR_DELIVERY or DELIVERED, set the user who performed it as deliveredBy
        if (status == Order.OrderStatus.OUT_FOR_DELIVERY || status == Order.OrderStatus.DELIVERED) {
            User performer = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("User not found"));
            order.setDeliveredBy(performer);
        }
        
        order = orderRepository.save(order);
        return convertToDto(order);
    }

    @Transactional
    public OrderDto cancelOrder(Long orderId, Long customerId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        if (!order.getCustomer().getId().equals(customerId)) {
            throw new RuntimeException("Not authorized to cancel this order");
        }
        if (order.getStatus() == Order.OrderStatus.DELIVERED || order.getStatus() == Order.OrderStatus.CANCELLED) {
            throw new RuntimeException("Order cannot be cancelled");
        }
        order.setStatus(Order.OrderStatus.CANCELLED);
        for (OrderItem item : order.getItems()) {
            Product product = item.getProduct();
            product.setStock(product.getStock() + item.getQuantity());
            productRepository.save(product);
        }
        order = orderRepository.save(order);
        return convertToDto(order);
    }

    @Transactional
    public void deleteOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        
        // Soft delete
        order.setDeleted(true);
        orderRepository.save(order);
    }

    @Transactional
    public void restoreOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        
        order.setDeleted(false);
        orderRepository.save(order);
    }

    @Transactional
    public OrderDto updateOrderItems(Long orderId, List<OrderItemDto> itemDtos) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        
        // Restore old stock
        for (OrderItem item : order.getItems()) {
            Product product = item.getProduct();
            product.setStock(product.getStock() + item.getQuantity());
            productRepository.save(product);
        }
        
        order.getItems().clear();
        BigDecimal totalAmount = BigDecimal.ZERO;
        
        for (OrderItemDto itemDto : itemDtos) {
            Product product = productRepository.findById(itemDto.getProductId())
                    .orElseThrow(() -> new RuntimeException("Product not found: " + itemDto.getProductId()));

            if (product.getStock() < itemDto.getQuantity()) {
                throw new RuntimeException("Insufficient stock for product: " + product.getName());
            }

            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProduct(product);
            
            int quantity = itemDto.getQuantity() != null ? itemDto.getQuantity() : 0;
            orderItem.setQuantity(quantity);
            
            BigDecimal price = itemDto.getPrice() != null ? itemDto.getPrice() : product.getSellingPrice();
            if (price == null) price = BigDecimal.ZERO;
            orderItem.setPrice(price);

            order.getItems().add(orderItem);
            totalAmount = totalAmount.add(price.multiply(BigDecimal.valueOf(quantity)));

            // Update product stock
            int currentStock = product.getStock() != null ? product.getStock() : 0;
            product.setStock(currentStock - quantity);
            productRepository.save(product);
        }

        order.setTotalAmount(totalAmount);
        order = orderRepository.save(order);

        return convertToDto(order);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getSalesReport(String type) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startDate;

        if ("DAILY".equals(type)) {
            startDate = now.withHour(0).withMinute(0).withSecond(0).withNano(0);
        } else if ("WEEKLY".equals(type)) {
            startDate = now.minusDays(7);
        } else if ("MONTHLY".equals(type)) {
            startDate = now.minusDays(30);
        } else {
            startDate = now.minusDays(1);
        }

        List<Order> orders = orderRepository.findAll().stream()
                .filter(o -> o.getCreatedAt() != null && o.getCreatedAt().isAfter(startDate) && o.getStatus() != Order.OrderStatus.CANCELLED)
                .collect(Collectors.toList());

        BigDecimal totalSales = orders.stream()
                .map(Order::getTotalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        Map<String, Object> result = new HashMap<>();
        result.put("totalSales", totalSales);
        result.put("totalOrders", orders.size());
        return result;
    }

    private OrderDto convertToDto(Order order) {
        OrderDto dto = new OrderDto();
        dto.setId(order.getId());
        dto.setCustomerId(order.getCustomer().getId());
        dto.setCustomerName(order.getCustomer().getName());
        dto.setCustomerAddress(order.getCustomer().getAddress());
        dto.setSellerId(order.getSeller().getId());
        dto.setSellerName(order.getSeller().getName());
        
        if (order.getDeliveredBy() != null) {
            dto.setDeliveredById(order.getDeliveredBy().getId());
            dto.setDeliveredByName(order.getDeliveredBy().getName());
        }
        
        dto.setTotalAmount(order.getTotalAmount());
        dto.setStatus(order.getStatus());
        dto.setCreatedAt(order.getCreatedAt());

        dto.setItems(order.getItems().stream().map(item -> {
            OrderItemDto itemDto = new OrderItemDto();
            itemDto.setProductId(item.getProduct().getId());
            itemDto.setProductName(item.getProduct().getName());
            itemDto.setQuantity(item.getQuantity());
            itemDto.setPrice(item.getPrice());
            return itemDto;
        }).collect(Collectors.toList()));

        return dto;
    }
}
