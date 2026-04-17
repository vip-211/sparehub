
package com.spareparts.inventory.exception;

import com.spareparts.inventory.dto.MessageResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<MessageResponse> handleRuntimeException(RuntimeException ex) {
        log.error("Runtime error caught: {}", ex.getMessage(), ex);
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(new MessageResponse(ex.getMessage()));
    }

    @ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
    public ResponseEntity<MessageResponse> handleDataIntegrityViolationException(org.springframework.dao.DataIntegrityViolationException ex) {
        log.error("Data integrity violation caught: {}", ex.getMessage());
        String message = "A data integrity error occurred.";
        if (ex.getMessage().contains("duplicate key value violates unique constraint")) {
            if (ex.getMessage().contains("part_number")) {
                message = "Error: A product with this part number already exists.";
            } else if (ex.getMessage().contains("uk_") || ex.getMessage().contains("unique constraint")) {
                message = "Error: A record with this unique value already exists.";
            }
        }
        return ResponseEntity
                .status(HttpStatus.CONFLICT)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(new MessageResponse(message));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        log.warn("Validation error: {}", ex.getMessage());
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
                errors.put(error.getField(), error.getDefaultMessage()));
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(errors);
    }

    @ExceptionHandler(org.springframework.web.HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<MessageResponse> handleMethodNotSupported(org.springframework.web.HttpRequestMethodNotSupportedException ex, jakarta.servlet.http.HttpServletRequest request) {
        log.warn("Method not supported: {} at {}", ex.getMessage(), request.getRequestURI());
        return ResponseEntity
                .status(HttpStatus.METHOD_NOT_ALLOWED)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(new MessageResponse("Request method '" + ex.getMethod() + "' is not supported for this endpoint."));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<MessageResponse> handleGenericException(Exception ex) {
        log.error("Internal error caught: {}", ex.getMessage(), ex);
        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(new MessageResponse("An internal error occurred: " + ex.getMessage()));
    }

    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotWritableException.class)
    public void handleMessageNotWritableException(org.springframework.http.converter.HttpMessageNotWritableException ex, jakarta.servlet.http.HttpServletResponse response) throws java.io.IOException {
        log.warn("HttpMessageNotWritableException caught: {}", ex.getMessage());

        try {
            if (!response.isCommitted()) {
                response.resetBuffer();
                response.setContentType("application/json");
                response.setStatus(HttpStatus.INTERNAL_SERVER_ERROR.value());
                response.getWriter().write("{\"message\":\"Error processing request\"}");
                response.getWriter().flush();
            }
        } catch (Exception e) {
            log.debug("Silent failure writing error response: {}", e.getMessage());
        }
    }
}
