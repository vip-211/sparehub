package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.CustomOrderRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface OrderRequestRepository extends JpaRepository<CustomOrderRequest, Long> {
    List<CustomOrderRequest> findByCustomerIdAndDeletedFalse(Long customerId);
    List<CustomOrderRequest> findAllByDeletedFalseOrderByCreatedAtDesc();
}
