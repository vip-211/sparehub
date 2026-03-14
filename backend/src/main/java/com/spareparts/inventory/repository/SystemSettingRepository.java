package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.SystemSetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SystemSettingRepository extends JpaRepository<SystemSetting, String> {
    default String getSettingValue(String key, String defaultValue) {
        return findById(key).map(SystemSetting::getSettingValue).orElse(defaultValue);
    }
}
