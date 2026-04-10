package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.SystemSetting;
import com.spareparts.inventory.repository.SystemSettingRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.cache.annotation.CacheEvict;

import java.util.Map;

@RestController
@RequestMapping("/api/cms")
public class CmsController {

    @Autowired
    private SystemSettingRepository systemSettingRepository;

    @GetMapping("/settings/{key}")
    @Cacheable(cacheNames = "cms_settings", key = "#key")
    public ResponseEntity<Map<String, String>> getCmsSetting(@PathVariable String key) {
        String value = systemSettingRepository.getSettingValue(key, "");
        return ResponseEntity.ok(Map.of("key", key, "value", value));
    }

    @PutMapping("/settings/{key}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    @CacheEvict(cacheNames = "cms_settings", key = "#key", allEntries = false)
    public ResponseEntity<Map<String, String>> updateCmsSetting(@PathVariable String key, @RequestBody Map<String, String> body) {
        String value = body.get("value");
        if (value == null) {
            return ResponseEntity.badRequest().build();
        }
        SystemSetting setting = new SystemSetting(key, value);
        systemSettingRepository.save(setting);
        return ResponseEntity.ok(Map.of("key", key, "value", value));
    }
}
