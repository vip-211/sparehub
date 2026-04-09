
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
    static String[] HEADERS = { "Name", "Part Number", "MRP", "Selling Price", "Stock", "Wholesaler Price", "Retailer Price", "Mechanic Price", "Rack Number", "Description", "Min Order Qty", "Image Links" };
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
                row.createCell(5).setCellValue(product.getWholesalerPrice().doubleValue());
                row.createCell(6).setCellValue(product.getRetailerPrice().doubleValue());
                row.createCell(7).setCellValue(product.getMechanicPrice().doubleValue());
                row.createCell(8).setCellValue(product.getRackNumber() != null ? product.getRackNumber() : "");
                row.createCell(9).setCellValue(product.getDescription() != null ? product.getDescription() : "");
                row.createCell(10).setCellValue(product.getMinOrderQty() != null ? product.getMinOrderQty() : 1);
                String imageLinks = product.getImageLinks() != null ? String.join(";", product.getImageLinks()) : "";
                row.createCell(11).setCellValue(imageLinks);
            }

            workbook.write(out);
            return new ByteArrayInputStream(out.toByteArray());
        } catch (IOException e) {
            throw new RuntimeException("fail to import data to Excel file: " + e.getMessage());
        }
    }

    public static List<Product> excelToProducts(InputStream is, User wholesaler) {
        try {
            Workbook workbook = WorkbookFactory.create(is);
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
                            // Default selling price to MRP if it's 0
                            if (product.getSellingPrice().compareTo(BigDecimal.ZERO) == 0 && product.getMrp().compareTo(BigDecimal.ZERO) > 0) {
                                product.setSellingPrice(product.getMrp());
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
                        case 5: // Wholesaler Price
                            if (currentCell.getCellType() == CellType.NUMERIC) {
                                product.setWholesalerPrice(BigDecimal.valueOf(currentCell.getNumericCellValue()));
                            } else {
                                String val = currentCell.toString().replaceAll("[^\\d.]", "");
                                if (val.isEmpty() || val.equals(".") || val.equals("null")) val = "0";
                                try {
                                    product.setWholesalerPrice(new BigDecimal(val));
                                } catch (Exception e) {
                                    product.setWholesalerPrice(BigDecimal.ZERO);
                                }
                            }
                            // Default to MRP if 0
                            if (product.getWholesalerPrice().compareTo(BigDecimal.ZERO) == 0 && product.getMrp().compareTo(BigDecimal.ZERO) > 0) {
                                product.setWholesalerPrice(product.getMrp());
                            }
                            break;
                        case 6: // Retailer Price
                            if (currentCell.getCellType() == CellType.NUMERIC) {
                                product.setRetailerPrice(BigDecimal.valueOf(currentCell.getNumericCellValue()));
                            } else {
                                String val = currentCell.toString().replaceAll("[^\\d.]", "");
                                if (val.isEmpty() || val.equals(".") || val.equals("null")) val = "0";
                                try {
                                    product.setRetailerPrice(new BigDecimal(val));
                                } catch (Exception e) {
                                    product.setRetailerPrice(BigDecimal.ZERO);
                                }
                            }
                            // Default to MRP if 0
                            if (product.getRetailerPrice().compareTo(BigDecimal.ZERO) == 0 && product.getMrp().compareTo(BigDecimal.ZERO) > 0) {
                                product.setRetailerPrice(product.getMrp());
                            }
                            break;
                        case 7: // Mechanic Price
                            if (currentCell.getCellType() == CellType.NUMERIC) {
                                product.setMechanicPrice(BigDecimal.valueOf(currentCell.getNumericCellValue()));
                            } else {
                                String val = currentCell.toString().replaceAll("[^\\d.]", "");
                                if (val.isEmpty() || val.equals(".") || val.equals("null")) val = "0";
                                try {
                                    product.setMechanicPrice(new BigDecimal(val));
                                } catch (Exception e) {
                                    product.setMechanicPrice(BigDecimal.ZERO);
                                }
                            }
                            // Default to MRP if 0
                            if (product.getMechanicPrice().compareTo(BigDecimal.ZERO) == 0 && product.getMrp().compareTo(BigDecimal.ZERO) > 0) {
                                product.setMechanicPrice(product.getMrp());
                            }
                            break;
                        case 8: // Rack Number
                            if (currentCell.getCellType() == CellType.STRING) {
                                product.setRackNumber(currentCell.getStringCellValue());
                            } else {
                                product.setRackNumber(currentCell.toString());
                            }
                            break;
                        case 9: // Description
                            if (currentCell.getCellType() == CellType.STRING) {
                                product.setDescription(currentCell.getStringCellValue());
                            } else {
                                product.setDescription(currentCell.toString());
                            }
                            break;
                        case 10: // Min Order Qty
                            if (currentCell.getCellType() == CellType.NUMERIC) {
                                product.setMinOrderQty((int) currentCell.getNumericCellValue());
                            } else {
                                String val = currentCell.toString().trim().replaceAll("[^\\d]", "");
                                if (val.isEmpty() || val.equals("null")) val = "1";
                                try {
                                    product.setMinOrderQty(Integer.parseInt(val));
                                } catch (Exception e) {
                                    product.setMinOrderQty(1);
                                }
                            }
                            break;
                        case 11: // Image Links
                            String linksStr = "";
                            if (currentCell.getCellType() == CellType.STRING) {
                                linksStr = currentCell.getStringCellValue();
                            } else {
                                linksStr = currentCell.toString();
                            }
                            if (!linksStr.isEmpty() && !linksStr.equals("null")) {
                                String[] links = linksStr.split(";");
                                java.util.List<String> list = new java.util.ArrayList<>();
                                for (String link : links) {
                                    if (!link.trim().isEmpty()) {
                                        list.add(link.trim());
                                    }
                                }
                                product.setImageLinks(list);
                            }
                            break;
                        default:
                            break;
                    }
                }
                if (product.getName() != null && !product.getName().isEmpty() && product.getPartNumber() != null && !product.getPartNumber().isEmpty()) {
                    products.add(product);
                } else {
                    System.out.println("Skipping invalid row " + rowNumber + ": Name=" + product.getName() + ", PartNumber=" + product.getPartNumber());
                }
            }
            workbook.close();
            return products;
        } catch (IOException e) {
            throw new RuntimeException("fail to parse Excel file: " + e.getMessage());
        }
    }
}
