package com.spareparts.inventory.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import jakarta.annotation.PostConstruct;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.UUID;

@CrossOrigin(origins = "${app.cors.allowed-origins}", maxAge = 3600)
@RestController
@RequestMapping("/api/files")
public class FileController {

    @Value("${app.upload.dir:uploads/}")
    private String uploadDir;

    @PostConstruct
    public void init() {
        try {
            Path root = Paths.get(uploadDir).toAbsolutePath().normalize();
            if (!Files.exists(root)) {
                Files.createDirectories(root);
                System.out.println("Created upload directory at: " + root.toString());
            } else {
                System.out.println("Using existing upload directory at: " + root.toString());
            }
        } catch (IOException e) {
            System.err.println("Could not initialize upload directory: " + e.getMessage());
        }
    }

    @PostMapping("/upload")
    public ResponseEntity<?> uploadFile(@RequestParam("file") MultipartFile file) {
        try {
            Path root = Paths.get(uploadDir).toAbsolutePath().normalize();
            if (!Files.exists(root)) {
                Files.createDirectories(root);
            }

            String filename = UUID.randomUUID().toString() + "_" + file.getOriginalFilename().replaceAll("\\s+", "_");
            Files.copy(file.getInputStream(), root.resolve(filename));

            System.out.println("File uploaded successfully: " + filename + " to " + root.toString());
            return ResponseEntity.ok(Map.of("url", "/api/files/display/" + filename));
        } catch (IOException e) {
            System.err.println("File upload failed: " + e.getMessage());
            return ResponseEntity.internalServerError().body("Could not upload file: " + e.getMessage());
        }
    }

    @GetMapping("/display/{filename:.+}")
    public ResponseEntity<Resource> displayFile(@PathVariable String filename) {
        try {
            Path root = Paths.get(uploadDir).toAbsolutePath().normalize();
            Path file = root.resolve(filename);
            Resource resource = new UrlResource(file.toUri());

            if (resource.exists() || resource.isReadable()) {
                String contentType = Files.probeContentType(file);
                if (contentType == null) {
                    contentType = "application/octet-stream";
                }
                return ResponseEntity.ok()
                        .contentType(MediaType.parseMediaType(contentType))
                        .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + resource.getFilename() + "\"")
                        .body(resource);
            } else {
                System.err.println("File not found for display: " + filename + " at " + file.toString());
                return ResponseEntity.notFound().build();
            }
        } catch (MalformedURLException e) {
            return ResponseEntity.internalServerError().build();
        } catch (IOException e) {
            return ResponseEntity.internalServerError().build();
        }
    }
}
