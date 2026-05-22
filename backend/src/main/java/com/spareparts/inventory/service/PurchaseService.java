package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.PurchaseDto;
import com.spareparts.inventory.entity.Purchase;
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
        String[] columns = {"Date", "Invoice Number", "Supplier", "Product", "Quantity", "Cost Price", "Selling Price", "GST", "Total", "Bill URL"};

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
                Row row = sheet.createRow(rowIdx++);

                row.createCell(0).setCellValue(p.getPurchaseDate().toString());
                row.createCell(1).setCellValue(p.getInvoiceNumber());
                row.createCell(2).setCellValue(p.getSupplierName());
                row.createCell(3).setCellValue(p.getProductName());
                row.createCell(4).setCellValue(p.getQuantity());
                row.createCell(5).setCellValue(p.getCostPrice().doubleValue());
                row.createCell(6).setCellValue(p.getSellingPrice() != null ? p.getSellingPrice().doubleValue() : 0.0);
                row.createCell(7).setCellValue(p.getGst() != null ? p.getGst().doubleValue() : 0.0);
                row.createCell(8).setCellValue(p.getTotalAmount().doubleValue());
                row.createCell(9).setCellValue(p.getBillImageUrl() != null ? p.getBillImageUrl() : p.getBillPdfUrl());
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
        purchase.setProductName(dto.getProductName());
        purchase.setPartNumber(dto.getPartNumber());
        purchase.setQuantity(dto.getQuantity());
        purchase.setCostPrice(dto.getCostPrice());
        purchase.setSellingPrice(dto.getSellingPrice());
        purchase.setGst(dto.getGst());
        purchase.setTotalAmount(dto.getTotalAmount());
        purchase.setNotes(dto.getNotes());
        purchase.setBillImageUrl(dto.getBillImageUrl());
        purchase.setBillPdfUrl(dto.getBillPdfUrl());
        purchase.setDailyAmount(dto.getDailyAmount());
        purchase.setRemainingAmount(dto.getRemainingAmount());
    }

    private PurchaseDto convertToDto(Purchase p) {
        PurchaseDto dto = new PurchaseDto();
        dto.setId(p.getId());
        dto.setSupplierName(p.getSupplierName());
        dto.setSupplierMobile(p.getSupplierMobile());
        dto.setInvoiceNumber(p.getInvoiceNumber());
        dto.setPurchaseDate(p.getPurchaseDate());
        dto.setProductName(p.getProductName());
        dto.setPartNumber(p.getPartNumber());
        dto.setQuantity(p.getQuantity());
        dto.setCostPrice(p.getCostPrice());
        dto.setSellingPrice(p.getSellingPrice());
        dto.setGst(p.getGst());
        dto.setTotalAmount(p.getTotalAmount());
        dto.setNotes(p.getNotes());
        dto.setBillImageUrl(p.getBillImageUrl());
        dto.setBillPdfUrl(p.getBillPdfUrl());
        dto.setDailyAmount(p.getDailyAmount());
        dto.setRemainingAmount(p.getRemainingAmount());
        if (p.getCreatedBy() != null) {
            dto.setCreatedById(p.getCreatedBy().getId());
            dto.setCreatedByName(p.getCreatedBy().getName());
        }
        dto.setCreatedAt(p.getCreatedAt());
        return dto;
    }
}
