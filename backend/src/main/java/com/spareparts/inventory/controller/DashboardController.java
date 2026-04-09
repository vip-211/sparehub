package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.DashboardConfig;
import com.spareparts.inventory.repository.DashboardConfigRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/dashboard")
public class DashboardController {

    @Autowired
    private DashboardConfigRepository configRepository;

    @GetMapping("/mechanic")
    public ResponseEntity<List<DashboardConfig>> getMechanicDashboard() {
        return ResponseEntity.ok(configRepository.findByTargetRoleAndEnabledTrueOrderByDisplayOrderAsc("ROLE_MECHANIC"));
    }

    @PostMapping("/config")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<DashboardConfig> saveConfig(@RequestBody DashboardConfig config) {
        return ResponseEntity.ok(configRepository.save(config));
    }

    @DeleteMapping("/config/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<?> deleteConfig(@PathVariable Long id) {
        configRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
