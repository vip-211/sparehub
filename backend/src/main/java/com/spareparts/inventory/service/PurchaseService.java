package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.PurchaseDto;
import com.spareparts.inventory.dto.PurchaseItemDto;
import com.spareparts.inventory.entity.Purchase;
import com.spareparts.inventory.entity.PurchaseItem;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.PurchaseRepository;
import com.spareparts.inventory.repository.UserRepository;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class PurchaseService {

    @Autowired
    private PurchaseRepository purchaseRepository;

    @Autowired
    private UserRepository userRepository;

    @Transactional
    public PurchaseDto createPurchase(PurchaseDto purchaseDto, Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Purchase purchase = new Purchase();
        updatePurchaseFromDto(purchase, purchaseDto);
        purchase.setCreatedBy(user);

        Purchase saved = purchaseRepository.save(purchase);
        return convertToDto(saved);
    }

    @Transactional
    public PurchaseDto updatePurchase(Long id, PurchaseDto purchaseDto) {
        Purchase purchase = purchaseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Purchase not found"));

        updatePurchaseFromDto(purchase, purchaseDto);
        Purchase updated = purchaseRepository.save(purchase);
        return convertToDto(updated);
    }

    @Transactional(readOnly = true)
    public List<PurchaseDto> getAllPurchases() {
        return purchaseRepository.findAll().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public PurchaseDto getPurchaseById(Long id) {
        Purchase purchase = purchaseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Purchase not found"));
        return convertToDto(purchase);
    }

    @Transactional
    public void deletePurchase(Long id) {
        purchaseRepository.deleteById(id);
    }

    @Transactional
    public void updateDailyPaidAmount(LocalDate date, BigDecimal amount) {
        List<Purchase> purchases = purchaseRepository.findByPurchaseDate(date);
        if (purchases.isEmpty()) return;

        // Reset all daily amounts for this date
        for (Purchase p : purchases) {
            p.setDailyAmount(BigDecimal.ZERO);
            p.setRemainingAmount(BigDecimal.ZERO);
        }

        // Set the total daily amount to the first purchase
        Purchase first = purchases.get(0);
        first.setDailyAmount(amount);
        
        // Calculate remaining for the group
        BigDecimal totalGroupAmount = purchases.stream()
                .map(Purchase::getTotalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        first.setRemainingAmount(amount.subtract(totalGroupAmount));
        
        purchaseRepository.saveAll(purchases);
    }

    @Transactional(readOnly = true)
    public List<PurchaseDto> getPurchasesByDateRange(LocalDate start, LocalDate end) {
        return purchaseRepository.findByPurchaseDateBetween(start, end).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<PurchaseDto> searchPurchases(String query) {
        return purchaseRepository.searchPurchases(query).stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    public ByteArrayInputStream exportToExcel(List<PurchaseDto> purchases) throws IOException {
        String[] columns = {"Date", "Invoice Number", "Supplier", "Product", "Part Number", "Quantity", "Cost Price", "Selling Price", "GST", "Total", "Discount", "Grand Total", "Bill URL"};

        try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sheet = workbook.createSheet("Purchases");

            Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerFont.setColor(IndexedColors.BLUE.getIndex());

            CellStyle headerCellStyle = workbook.createCellStyle();
            headerCellStyle.setFont(headerFont);

            Row headerRow = sheet.createRow(0);

            for (int col = 0; col < columns.length; col++) {
                Cell cell = headerRow.createCell(col);
                cell.setCellValue(columns[col]);
                cell.setCellStyle(headerCellStyle);
            }

            int rowIdx = 1;
            for (PurchaseDto p : purchases) {
                if (p.getItems() != null && !p.getItems().isEmpty()) {
                    for (PurchaseItemDto item : p.getItems()) {
                        Row row = sheet.createRow(rowIdx++);
                        row.createCell(0).setCellValue(p.getPurchaseDate().toString());
                        row.createCell(1).setCellValue(p.getInvoiceNumber());
                        row.createCell(2).setCellValue(p.getSupplierName());
                        row.createCell(3).setCellValue(item.getProductName());
                        row.createCell(4).setCellValue(item.getPartNumber());
                        row.createCell(5).setCellValue(item.getQuantity());
                        row.createCell(6).setCellValue(item.getCostPrice().doubleValue());
                        row.createCell(7).setCellValue(item.getSellingPrice() != null ? item.getSellingPrice().doubleValue() : 0.0);
                        row.createCell(8).setCellValue(item.getGst() != null ? item.getGst().doubleValue() : 0.0);
                        row.createCell(9).setCellValue(item.getTotalAmount().doubleValue());
                        row.createCell(10).setCellValue(p.getDiscount() != null ? p.getDiscount().doubleValue() : 0.0);
                        row.createCell(11).setCellValue(p.getTotalAmount().doubleValue());
                        row.createCell(12).setCellValue(p.getBillImageUrl() != null ? p.getBillImageUrl() : p.getBillPdfUrl());
                    }
                } else {
                    Row row = sheet.createRow(rowIdx++);
                    row.createCell(0).setCellValue(p.getPurchaseDate().toString());
                    row.createCell(1).setCellValue(p.getInvoiceNumber());
                    row.createCell(2).setCellValue(p.getSupplierName());
                    row.createCell(3).setCellValue("-");
                    row.createCell(4).setCellValue("-");
                    row.createCell(5).setCellValue(0);
                    row.createCell(6).setCellValue(0.0);
                    row.createCell(7).setCellValue(0.0);
                    row.createCell(8).setCellValue(0.0);
                    row.createCell(9).setCellValue(0.0);
                    row.createCell(10).setCellValue(p.getDiscount() != null ? p.getDiscount().doubleValue() : 0.0);
                    row.createCell(11).setCellValue(p.getTotalAmount().doubleValue());
                    row.createCell(12).setCellValue(p.getBillImageUrl() != null ? p.getBillImageUrl() : p.getBillPdfUrl());
                }
            }

            workbook.write(out);
            return new ByteArrayInputStream(out.toByteArray());
        }
    }

    private void updatePurchaseFromDto(Purchase purchase, PurchaseDto dto) {
        purchase.setSupplierName(dto.getSupplierName());
        purchase.setSupplierMobile(dto.getSupplierMobile());
        purchase.setInvoiceNumber(dto.getInvoiceNumber());
        purchase.setPurchaseDate(dto.getPurchaseDate());
        purchase.setDiscount(dto.getDiscount());
        purchase.setTotalAmount(dto.getTotalAmount());
        purchase.setNotes(dto.getNotes());
        purchase.setBillImageUrl(dto.getBillImageUrl());
        purchase.setBillPdfUrl(dto.getBillPdfUrl());
        purchase.setCostPrice(dto.getCostPrice() != null ? dto.getCostPrice() : BigDecimal.ZERO);
        purchase.setQuantity(dto.getQuantity() != null ? dto.getQuantity() : 0);
        purchase.setDailyAmount(dto.getDailyAmount());
        purchase.setRemainingAmount(dto.getRemainingAmount());

        // Update items
        if (purchase.getItems() != null) {
            purchase.getItems().clear();
        } else {
            purchase.setItems(new java.util.ArrayList<>());
        }

        if (dto.getItems() != null) {
            for (PurchaseItemDto itemDto : dto.getItems()) {
                PurchaseItem item = new PurchaseItem();
                item.setPurchase(purchase);
                item.setProductName(itemDto.getProductName());
                item.setPartNumber(itemDto.getPartNumber());
                item.setQuantity(itemDto.getQuantity());
                item.setCostPrice(itemDto.getCostPrice());
                item.setSellingPrice(itemDto.getSellingPrice());
                item.setGst(itemDto.getGst());
                item.setTotalAmount(itemDto.getTotalAmount());
                purchase.getItems().add(item);
            }
        }
    }

    private PurchaseDto convertToDto(Purchase p) {
        PurchaseDto dto = new PurchaseDto();
        dto.setId(p.getId());
        dto.setSupplierName(p.getSupplierName());
        dto.setSupplierMobile(p.getSupplierMobile());
        dto.setInvoiceNumber(p.getInvoiceNumber());
        dto.setPurchaseDate(p.getPurchaseDate());
        dto.setDiscount(p.getDiscount());
        dto.setTotalAmount(p.getTotalAmount());
        dto.setNotes(p.getNotes());
        dto.setBillImageUrl(p.getBillImageUrl());
        dto.setBillPdfUrl(p.getBillPdfUrl());
        dto.setCostPrice(p.getCostPrice());
        dto.setQuantity(p.getQuantity());
        dto.setDailyAmount(p.getDailyAmount());
        dto.setRemainingAmount(p.getRemainingAmount());
        
        if (p.getItems() != null) {
            dto.setItems(p.getItems().stream().map(item -> {
                PurchaseItemDto itemDto = new PurchaseItemDto();
                itemDto.setId(item.getId());
                itemDto.setProductName(item.getProductName());
                itemDto.setPartNumber(item.getPartNumber());
                itemDto.setQuantity(item.getQuantity());
                itemDto.setCostPrice(item.getCostPrice());
                itemDto.setSellingPrice(item.getSellingPrice());
                itemDto.setGst(item.getGst());
                itemDto.setTotalAmount(item.getTotalAmount());
                return itemDto;
            }).collect(Collectors.toList()));
        }

        if (p.getCreatedBy() != null) {
            dto.setCreatedById(p.getCreatedBy().getId());
            dto.setCreatedByName(p.getCreatedBy().getName());
        }
        dto.setCreatedAt(p.getCreatedAt());
        return dto;
    }
}
