
package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Order;
import com.spareparts.inventory.entity.User;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.Pageable;

@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    @EntityGraph(attributePaths = {"customer", "seller", "items", "items.product"})
    List<Order> findByCustomerAndDeletedFalse(User customer);

    @EntityGraph(attributePaths = {"customer", "seller", "items", "items.product"})
    List<Order> findBySellerAndDeletedFalse(User seller);

    List<Order> findByStatusAndDeletedFalse(Order.OrderStatus status);
    
    List<Order> findByDeletedFalse();
    List<Order> findByDeletedTrue();

    @Query("SELECT o FROM Order o WHERE o.createdAt >= :since AND o.deleted = false")
    List<Order> findLast30Days(@Param("since") LocalDateTime since);

    @Query("SELECT i.product.name as name, SUM(i.quantity) as count FROM OrderItem i WHERE i.order.deleted = false GROUP BY i.product.name ORDER BY count DESC")
    List<Map<String, Object>> findTopSellingProducts(Pageable pageable);

    @Query("SELECT TO_CHAR(o.createdAt, 'YYYY-MM') as month, SUM(o.totalAmount) as total FROM Order o WHERE o.deleted = false GROUP BY TO_CHAR(o.createdAt, 'YYYY-MM') ORDER BY month ASC")
    List<Map<String, Object>> getMonthlySales();
}
