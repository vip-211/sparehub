
package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.entity.User;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class ExcelHelper {
    public static String[] TYPE = {
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-excel"
    };
    static String[] HEADERS = { "Name", "Part Number", "MRP", "Selling Price", "Stock" };
    static String SHEET = "Products";

    public static boolean hasExcelFormat(MultipartFile file) {
        String contentType = file.getContentType();
        if (contentType == null) return false;
        for (String type : TYPE) {
            if (type.equals(contentType)) return true;
        }
        return false;
    }

    public static ByteArrayInputStream productsToExcel(List<Product> products) {
        try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream();) {
            Sheet sheet = workbook.createSheet(SHEET);

            // Header
            Row headerRow = sheet.createRow(0);
            for (int col = 0; col < HEADERS.length; col++) {
                Cell cell = headerRow.createCell(col);
                cell.setCellValue(HEADERS[col]);
            }

            int rowIdx = 1;
            for (Product product : products) {
                Row row = sheet.createRow(rowIdx++);

                row.createCell(0).setCellValue(product.getName());
                row.createCell(1).setCellValue(product.getPartNumber());
                row.createCell(2).setCellValue(product.getMrp().doubleValue());
                row.createCell(3).setCellValue(product.getSellingPrice().doubleValue());
                row.createCell(4).setCellValue(product.getStock());
            }

            workbook.write(out);
            return new ByteArrayInputStream(out.toByteArray());
        } catch (IOException e) {
            throw new RuntimeException("fail to import data to Excel file: " + e.getMessage());
        }
    }

    public static List<Product> excelToProducts(InputStream is, User wholesaler) {
        try {
            Workbook workbook = new XSSFWorkbook(is);
            Sheet sheet = workbook.getSheet(SHEET);
            if (sheet == null) {
                sheet = workbook.getSheetAt(0);
            }

            Iterator<Row> rows = sheet.iterator();
            List<Product> products = new ArrayList<>();

            int rowNumber = 0;
            while (rows.hasNext()) {
                Row currentRow = rows.next();

                // Skip header
                if (rowNumber == 0) {
                    rowNumber++;
                    continue;
                }

                Product product = new Product();
                product.setWholesaler(wholesaler);

                for (int cellIdx = 0; cellIdx < HEADERS.length; cellIdx++) {
                    Cell currentCell = currentRow.getCell(cellIdx, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK);
                    
                    switch (cellIdx) {
                        case 0: // Name
                            if (currentCell.getCellType() == CellType.STRING) {
                                product.setName(currentCell.getStringCellValue());
                            } else {
                                product.setName(currentCell.toString());
                            }
                            break;
                        case 1: // Part Number
                            if (currentCell.getCellType() == CellType.STRING) {
                                product.setPartNumber(currentCell.getStringCellValue());
                            } else {
                                product.setPartNumber(currentCell.toString());
                            }
                            break;
                        case 2: // MRP
                            if (currentCell.getCellType() == CellType.NUMERIC) {
                                product.setMrp(BigDecimal.valueOf(currentCell.getNumericCellValue()));
                            } else {
                                String val = currentCell.toString().replaceAll("[^\\d.]", "");
                                if (val.isEmpty() || val.equals(".") || val.equals("null")) val = "0";
                                try {
                                    product.setMrp(new BigDecimal(val));
                                } catch (Exception e) {
                                    product.setMrp(BigDecimal.ZERO);
                                }
                            }
                            break;
                        case 3: // Selling Price
                            if (currentCell.getCellType() == CellType.NUMERIC) {
                                product.setSellingPrice(BigDecimal.valueOf(currentCell.getNumericCellValue()));
                            } else {
                                String val = currentCell.toString().replaceAll("[^\\d.]", "");
                                if (val.isEmpty() || val.equals(".") || val.equals("null")) val = "0";
                                try {
                                    product.setSellingPrice(new BigDecimal(val));
                                } catch (Exception e) {
                                    product.setSellingPrice(BigDecimal.ZERO);
                                }
                            }
                            break;
                        case 4: // Stock
                            if (currentCell.getCellType() == CellType.NUMERIC) {
                                product.setStock((int) currentCell.getNumericCellValue());
                            } else {
                                String val = currentCell.toString().trim();
                                if (val.contains(".")) {
                                    val = val.substring(0, val.indexOf("."));
                                }
                                val = val.replaceAll("[^\\d]", "");
                                if (val.isEmpty() || val.equals("null")) val = "0";
                                try {
                                    product.setStock(Integer.parseInt(val));
                                } catch (Exception e) {
                                    product.setStock(0);
                                }
                            }
                            break;
                        default:
                            break;
                    }
                }
                if (product.getName() != null && !product.getName().isEmpty()) {
                    products.add(product);
                }
            }
            workbook.close();
            return products;
        } catch (IOException e) {
            throw new RuntimeException("fail to parse Excel file: " + e.getMessage());
        }
    }
}
