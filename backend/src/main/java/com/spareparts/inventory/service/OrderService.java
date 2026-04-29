
package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.*;
import com.spareparts.inventory.dto.OrderRequest;
import com.spareparts.inventory.entity.*;
import com.spareparts.inventory.repository.OrderRepository;
import com.spareparts.inventory.repository.OrderRequestRepository;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.repository.SystemSettingRepository;
import com.spareparts.inventory.repository.BannerRepository;
import com.spareparts.inventory.repository.OfferRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.stream.Collectors;

@Service
public class OrderService {
    private static final Logger log = LoggerFactory.getLogger(OrderService.class);
    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private OrderRequestRepository orderRequestRepository;
    
    @Autowired
    private BannerRepository bannerRepository;
    
    @Autowired
    private OfferRepository offerRepository;
    
    @Autowired
    private FcmService fcmService;
    
    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Autowired
    private SystemSettingRepository systemSettingRepository;

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
        CustomOrderRequestDto dto = convertToCustomRequestDto(request);
        
        // Notify Admin, Super Manager, and Staff when user creates a custom order request
        try {
            String title = "New Custom Order Request #" + request.getId();
            String message = "New custom order request from " + customer.getName();
            
            fcmService.sendToRole("ROLE_ADMIN", title, message, "DAILY", null, "offers", null);
            fcmService.sendToRole("ROLE_SUPER_MANAGER", title, message, "DAILY", null, "offers", null);
            fcmService.sendToRole("ROLE_STAFF", title, message, "DAILY", null, "offers", null);
            
            // Real-time update for admin dashboard
            messagingTemplate.convertAndSend("/topic/admin/orders", dto);
        } catch (Exception e) {
            log.error("Failed to notify staff of new custom order request: {}", e.getMessage());
        }
        
        return dto;
    }

    @Transactional(readOnly = true)
    public List<CustomOrderRequestDto> getAllCustomOrderRequests() {
        return orderRequestRepository.findAllByDeletedFalseOrderByCreatedAtDesc().stream()
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
        CustomOrderRequestDto dto = convertToCustomRequestDto(request);
        
        try {
            // Real-time update for customer only
            messagingTemplate.convertAndSendToUser(request.getCustomer().getId().toString(), "/queue/orders", dto);
        } catch (Exception ignored) {}
        
        try {
            // Only notify the customer (respected user) when status is updated
            String title = "Custom Order #" + request.getId() + " updated";
            String body = "Your custom order request status is " + status;
            fcmService.sendOrderStatusToUser(request.getCustomer().getId(), request.getId(), title, body);
        } catch (Exception e) {
            log.error("Error sending custom order status notification to customer: {}", e.getMessage());
        }
        
        return dto;
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
        log.debug("Creating order for customerId: {} and sellerId: {}", customerId, orderRequest.getSellerId());
        
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
            log.debug("Processing item: {} (ID: {})", itemDto.getProductName(), itemDto.getProductId());
            Product product = productRepository.findById(itemDto.getProductId())
                    .orElseThrow(() -> new RuntimeException("Product not found: " + itemDto.getProductId()));

            int quantity = itemDto.getQuantity() != null ? itemDto.getQuantity() : 0;
            
            // Banner validation
            if (itemDto.getBannerId() != null) {
                Banner banner = bannerRepository.findById(itemDto.getBannerId())
                        .orElseThrow(() -> new RuntimeException("Banner not found: " + itemDto.getBannerId()));
                
                if (banner.isBuyEnabled() && banner.getProductId().equals(product.getId())) {
                    if (banner.isQuantityLocked() && quantity != banner.getMinimumQuantity()) {
                        throw new RuntimeException("Banner offer requires exactly " + banner.getMinimumQuantity() + " units for " + product.getName());
                    }
                    if (quantity < banner.getMinimumQuantity()) {
                        throw new RuntimeException("Banner offer requires minimum " + banner.getMinimumQuantity() + " units for " + product.getName());
                    }
                }
            }

            // Offer validation
            if (itemDto.getOfferId() != null) {
                Offer offer = offerRepository.findById(itemDto.getOfferId())
                        .orElseThrow(() -> new RuntimeException("Offer not found: " + itemDto.getOfferId()));
                
                if (offer.isActive() && offer.getProduct().getId().equals(product.getId())) {
                    if (offer.isQuantityLocked() && quantity != offer.getMinimumQuantity()) {
                        throw new RuntimeException("Offer requires exactly " + offer.getMinimumQuantity() + " units for " + product.getName());
                    }
                    if (quantity < offer.getMinimumQuantity()) {
                        throw new RuntimeException("Offer requires minimum " + offer.getMinimumQuantity() + " units for " + product.getName());
                    }
                }
            }

            if (product.getStock() < quantity) {
                log.error("Insufficient stock for {}. Available: {}, Requested: {}", product.getName(), product.getStock(), quantity);
                throw new RuntimeException("Insufficient stock for product: " + product.getName() + " (Available: " + product.getStock() + ")");
            }

            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProduct(product);
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

        // Points logic: Redeem points if requested
        if (orderRequest.getPointsToRedeem() != null && orderRequest.getPointsToRedeem() > 0) {
            long pointsToRedeem = orderRequest.getPointsToRedeem();
            if (customer.getPoints() < pointsToRedeem) {
                throw new RuntimeException("Insufficient points to redeem. Available: " + customer.getPoints());
            }
            long minRedeem = 0L;
            try {
                if (systemSettingRepository != null) {
                    minRedeem = Long.parseLong(systemSettingRepository.getSettingValue("MIN_REDEEM_POINTS", "0"));
                }
            } catch (Exception ignored) {}
            if (minRedeem > 0 && customer.getPoints() < minRedeem) {
                throw new RuntimeException("Minimum points required to redeem is " + minRedeem);
            }
            if (minRedeem > 0 && pointsToRedeem < minRedeem) {
                throw new RuntimeException("You must redeem at least " + minRedeem + " points");
            }
            
            // Assume 1 point = 1 unit of currency for simplicity, or apply conversion rate
            BigDecimal pointsValue = BigDecimal.valueOf(pointsToRedeem);
            if (pointsValue.compareTo(totalAmount) > 0) {
                pointsValue = totalAmount; // Cannot redeem more than total amount
                pointsToRedeem = pointsValue.longValue();
            }
            
            order.setPointsRedeemed(pointsToRedeem);
            order.setTotalAmount(totalAmount.subtract(pointsValue));
            
            // Deduct points from user
            customer.setPoints(customer.getPoints() - pointsToRedeem);
            userRepository.save(customer);
        }

        order = orderRepository.save(order);
        System.out.println("Order created successfully with ID: " + order.getId());

        OrderDto dto = convertToDto(order);

        // Notify relevant roles when user creates an order
        try {
            String title = "New Order #" + order.getId();
            String message = "New order received from " + customer.getName() + " for Rs. " + order.getTotalAmount();
            
            // 1. Always notify the Seller (Wholesaler) directly
            fcmService.sendOrderStatusToUser(seller.getId(), order.getId(), title, message);

            // 2. Notify all Staff
            fcmService.sendToRole("ROLE_STAFF", title, message, "DAILY", null, "orders", order.getId());

            // 3. Notify Admin and Super Manager
            fcmService.sendToRole("ROLE_ADMIN", title, message, "DAILY", null, "orders", order.getId());
            fcmService.sendToRole("ROLE_SUPER_MANAGER", title, message, "DAILY", null, "orders", order.getId());
            
            if (customer.getRole() != null && customer.getRole().getName() == RoleName.ROLE_MECHANIC) {
                if (order.getPointsRedeemed() != null && order.getPointsRedeemed() > 0) {
                    String redeemMsg = customer.getName() + " redeemed " + order.getPointsRedeemed() + " points (₹" + order.getPointsRedeemed() + ") on Order #" + order.getId();
                    fcmService.sendToRole("ROLE_ADMIN", "Points Redeemed", redeemMsg, "DAILY", null);
                    fcmService.sendToRole("ROLE_SUPER_MANAGER", "Points Redeemed", redeemMsg, "DAILY", null);
                }
            }
            
            // Real-time update for admin dashboard - Restricted topic
            messagingTemplate.convertAndSend("/topic/admin/orders", dto);
        } catch (Exception e) {
            log.error("Failed to notify administrators of new order: {}", e.getMessage());
        }

        return dto;
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

        BigDecimal subtotal = BigDecimal.ZERO;
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
            subtotal = subtotal.add(price.multiply(BigDecimal.valueOf(quantity)));

            // Update product stock
            int currentStock = product.getStock() != null ? product.getStock() : 0;
            product.setStock(currentStock - quantity);
            productRepository.save(product);
        }

        BigDecimal discountAmount = orderRequest.getDiscountAmount() != null ? orderRequest.getDiscountAmount() : BigDecimal.ZERO;
        order.setDiscountAmount(discountAmount);
        BigDecimal totalAmount = subtotal.subtract(discountAmount).max(BigDecimal.ZERO);
        order.setTotalAmount(totalAmount);
        order = orderRepository.save(order);
        OrderDto dto = convertToDto(order);

        try {
            // Real-time update for customer only
            messagingTemplate.convertAndSendToUser(order.getCustomer().getId().toString(), "/queue/orders", dto);
        } catch (Exception ignored) {}

        try {
            // Only notify the customer (respected user) when order is created by admin
            String title = "New Order Created for You #" + order.getId();
            String body = "An admin has created an order for you. Status: " + order.getStatus();
            fcmService.sendOrderStatusToUser(order.getCustomer().getId(), order.getId(), title, body);
        } catch (Exception e) {
            System.err.println("Error sending admin order creation notification to customer: " + e.getMessage());
        }

        return dto;
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
    public List<OrderDto> getStaffOrders(Long staffId) {
        // Staff should see orders assigned to them OR orders that are APPROVED and need delivery
        return orderRepository.findByDeletedFalse().stream()
                .filter(o -> (o.getDeliveredBy() != null && o.getDeliveredBy().getId().equals(staffId)) 
                        || o.getStatus() == Order.OrderStatus.APPROVED 
                        || o.getStatus() == Order.OrderStatus.PACKED
                        || o.getStatus() == Order.OrderStatus.OUT_FOR_DELIVERY)
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
        
        Order.OrderStatus oldStatus = order.getStatus();
        order.setStatus(status);
        
        // If status is OUT_FOR_DELIVERY or DELIVERED, set the user who performed it as deliveredBy
        if (status == Order.OrderStatus.OUT_FOR_DELIVERY || status == Order.OrderStatus.DELIVERED) {
            User performer = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("User not found"));
            order.setDeliveredBy(performer);
        }

        // Cashback points logic: Award points when order is DELIVERED
        if (status == Order.OrderStatus.DELIVERED && oldStatus != Order.OrderStatus.DELIVERED) {
            // Calculate cashback using configurable percentage (default 1%)
            BigDecimal cashbackPercentage = new BigDecimal("0.01");
            try {
                if (systemSettingRepository != null) {
                    String percentStr = systemSettingRepository.getSettingValue("LOYALTY_PERCENT", "1");
                    cashbackPercentage = new BigDecimal(percentStr).divide(new BigDecimal("100"));
                }
            } catch (Exception ignored) {}
            BigDecimal cashbackAmount = order.getTotalAmount().multiply(cashbackPercentage);
            long pointsEarned = cashbackAmount.longValue(); // Conversion 1 unit = 1 point

            if (pointsEarned > 0) {
                User customer = order.getCustomer();
                customer.setPoints(customer.getPoints() + pointsEarned);
                userRepository.save(customer);
                
                order.setPointsEarned(pointsEarned);
                
                System.out.println("Awarded " + pointsEarned + " points to user " + customer.getId() + " for order " + orderId + " by Parts Mitra");
            }
        }

        order = orderRepository.save(order);
        
        OrderDto dto = convertToDto(order);
        
        try {
            // Real-time update for customer only
            messagingTemplate.convertAndSendToUser(order.getCustomer().getId().toString(), "/queue/orders", dto);
        } catch (Exception ignored) {}
        
        try {
            // Only notify the customer (respected user) when status is updated
            String title = "Order #" + order.getId() + " " + status.name().replace('_', ' ').toLowerCase();
            String body = "Your order status is " + status.name();
            fcmService.sendOrderStatusToUser(order.getCustomer().getId(), order.getId(), title, body);
        } catch (Exception e) {
            System.err.println("Error sending order status notification to customer: " + e.getMessage());
        }
        
        return dto;
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
    public void deleteOrderPermanent(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        orderRepository.delete(order);
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
        BigDecimal subtotal = BigDecimal.ZERO;
        
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
            subtotal = subtotal.add(price.multiply(BigDecimal.valueOf(quantity)));

            // Update product stock
            int currentStock = product.getStock() != null ? product.getStock() : 0;
            product.setStock(currentStock - quantity);
            productRepository.save(product);
        }

        BigDecimal discountAmount = order.getDiscountAmount() != null ? order.getDiscountAmount() : BigDecimal.ZERO;
        BigDecimal totalAmount = subtotal.subtract(discountAmount).max(BigDecimal.ZERO);
        order.setTotalAmount(totalAmount);
        order = orderRepository.save(order);
        OrderDto dto = convertToDto(order);

        try {
            // Real-time update for customer only
            messagingTemplate.convertAndSendToUser(order.getCustomer().getId().toString(), "/queue/orders", dto);
        } catch (Exception ignored) {}

        try {
            // Only notify the customer (respected user) when order items are updated by admin
            String title = "Order #" + order.getId() + " Items Updated";
            String body = "An admin has updated the items in your order. New Total: Rs. " + order.getTotalAmount();
            fcmService.sendOrderStatusToUser(order.getCustomer().getId(), order.getId(), title, body);
        } catch (Exception e) {
            System.err.println("Error sending order update notification to customer: " + e.getMessage());
        }

        return dto;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getSalesReport(String type) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startDate;
        int intervals;
        java.util.function.Function<LocalDateTime, String> labelFunc;

        if ("DAILY".equals(type)) {
            startDate = now.withHour(0).withMinute(0).withSecond(0).withNano(0);
            intervals = 24;
            labelFunc = (dt) -> String.format("%02d:00", dt.getHour());
        } else if ("WEEKLY".equals(type)) {
            startDate = now.minusDays(7).withHour(0).withMinute(0).withSecond(0).withNano(0);
            intervals = 7;
            labelFunc = (dt) -> dt.getDayOfWeek().name().substring(0, 3);
        } else if ("MONTHLY".equals(type)) {
            startDate = now.minusDays(30).withHour(0).withMinute(0).withSecond(0).withNano(0);
            intervals = 30;
            labelFunc = (dt) -> String.valueOf(dt.getDayOfMonth());
        } else {
            startDate = now.minusDays(1);
            intervals = 1;
            labelFunc = (dt) -> "Total";
        }

        List<Order> orders = orderRepository.findAll().stream()
                .filter(o -> o.getCreatedAt() != null && o.getCreatedAt().isAfter(startDate) && o.getStatus() != Order.OrderStatus.CANCELLED)
                .collect(Collectors.toList());

        BigDecimal totalSales = orders.stream()
                .map(Order::getTotalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Calculate chart data
        List<Map<String, Object>> chartData = new ArrayList<>();
        for (int i = 0; i <= intervals; i++) {
            LocalDateTime current;
            if ("DAILY".equals(type)) current = startDate.plusHours(i);
            else current = startDate.plusDays(i);
            
            if (current.isAfter(now) && !"DAILY".equals(type)) break;
            if (current.isAfter(now.plusHours(1)) && "DAILY".equals(type)) break;

            LocalDateTime next;
            if ("DAILY".equals(type)) next = current.plusHours(1);
            else next = current.plusDays(1);

            BigDecimal periodSales = orders.stream()
                .filter(o -> o.getCreatedAt().isAfter(current) && o.getCreatedAt().isBefore(next))
                .map(Order::getTotalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

            Map<String, Object> dataPoint = new HashMap<>();
            dataPoint.put("name", labelFunc.apply(current));
            dataPoint.put("sales", periodSales);
            chartData.add(dataPoint);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("totalSales", totalSales);
        result.put("totalOrders", orders.size());
        result.put("chartData", chartData);
        return result;
    }

    private OrderDto convertToDto(Order order) {
        OrderDto dto = new OrderDto();
        dto.setId(order.getId());
        dto.setCustomerId(order.getCustomer().getId());
        dto.setCustomerName(order.getCustomer().getName());
        dto.setCustomerPhone(order.getCustomer().getPhone());
        dto.setCustomerAddress(order.getCustomer().getAddress());
        dto.setSellerId(order.getSeller().getId());
        dto.setSellerName(order.getSeller().getName());
        
        if (order.getDeliveredBy() != null) {
            dto.setDeliveredById(order.getDeliveredBy().getId());
            dto.setDeliveredByName(order.getDeliveredBy().getName());
        }
        
        dto.setTotalAmount(order.getTotalAmount());
        dto.setStatus(order.getStatus());
        dto.setPointsRedeemed(order.getPointsRedeemed());
        dto.setPointsEarned(order.getPointsEarned());
        dto.setDiscountAmount(order.getDiscountAmount());
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
