package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.DashboardConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DashboardConfigRepository extends JpaRepository<DashboardConfig, Long> {
    List<DashboardConfig> findByTargetRoleAndEnabledTrueOrderByDisplayOrderAsc(String targetRole);
}
