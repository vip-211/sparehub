package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.PurchaseDto;
import com.spareparts.inventory.security.UserDetailsImpl;
import com.spareparts.inventory.service.AIService;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import com.spareparts.inventory.service.PurchaseService;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/purchases")
public class PurchaseController {

    @Autowired
    private PurchaseService purchaseService;

    @Autowired
    private AIService aiService;

    @PostMapping("/scan-bill")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<String> scanBill(@RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(aiService.parseBillImage(file));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<PurchaseDto> createPurchase(@RequestBody PurchaseDto purchaseDto, @AuthenticationPrincipal UserDetailsImpl userDetails) {
        return ResponseEntity.ok(purchaseService.createPurchase(purchaseDto, userDetails.getId()));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<PurchaseDto> updatePurchase(@PathVariable Long id, @RequestBody PurchaseDto purchaseDto) {
        return ResponseEntity.ok(purchaseService.updatePurchase(id, purchaseDto));
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<List<PurchaseDto>> getAllPurchases() {
        return ResponseEntity.ok(purchaseService.getAllPurchases());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<PurchaseDto> getPurchaseById(@PathVariable Long id) {
        return ResponseEntity.ok(purchaseService.getPurchaseById(id));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<Void> deletePurchase(@PathVariable Long id) {
        purchaseService.deletePurchase(id);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/daily-paid")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<Void> updateDailyPaid(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam java.math.BigDecimal amount) {
        purchaseService.updateDailyPaidAmount(date, amount);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/by-range")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<List<PurchaseDto>> getPurchasesByRange(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate start,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate end) {
        return ResponseEntity.ok(purchaseService.getPurchasesByDateRange(start, end));
    }

    @GetMapping("/search")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<List<PurchaseDto>> searchPurchases(@RequestParam String query) {
        return ResponseEntity.ok(purchaseService.searchPurchases(query));
    }

    @GetMapping("/export/excel")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<Resource> exportExcel(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate start,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate end) throws IOException {
        
        List<PurchaseDto> purchases;
        if (start != null && end != null) {
            purchases = purchaseService.getPurchasesByDateRange(start, end);
        } else {
            purchases = purchaseService.getAllPurchases();
        }

        String filename = "purchases.xlsx";
        InputStreamResource file = new InputStreamResource(purchaseService.exportToExcel(purchases));

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=" + filename)
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(file);
    }
}
