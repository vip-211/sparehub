
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.MessageResponse;
import com.spareparts.inventory.security.UserDetailsImpl;
import com.spareparts.inventory.service.ExcelHelper;
import com.spareparts.inventory.service.ExcelService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/excel")
public class ExcelController {
    @Autowired
    private ExcelService fileService;

    @PostMapping("/upload")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<MessageResponse> uploadFile(
            @RequestParam("file") MultipartFile file, 
            @RequestParam(value = "categoryId", required = false) Long categoryId,
            Authentication authentication) {
        String message = "";

        if (ExcelHelper.hasExcelFormat(file)) {
            try {
                UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
                fileService.save(file, userDetails.getId(), categoryId);

                message = "Uploaded the file successfully: " + file.getOriginalFilename();
                return ResponseEntity.status(HttpStatus.OK).body(new MessageResponse(message));
            } catch (Exception e) {
                message = "Could not upload the file: " + file.getOriginalFilename() + "!";
                return ResponseEntity.status(HttpStatus.EXPECTATION_FAILED).body(new MessageResponse(message));
            }
        }

        message = "Please upload an excel file!";
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(new MessageResponse(message));
    }

    @GetMapping("/download")
    @PreAuthorize("hasRole('WHOLESALER') or hasRole('ADMIN') or hasRole('SUPER_MANAGER')")
    public ResponseEntity<Resource> getFile() {
        String filename = "products.xlsx";
        InputStreamResource file = new InputStreamResource(fileService.load());

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=" + filename)
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(file);
    }
}
