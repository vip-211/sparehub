
package com.spareparts.inventory.exception;

import com.spareparts.inventory.dto.MessageResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<MessageResponse> handleRuntimeException(RuntimeException ex) {
        System.err.println("Runtime error caught in GlobalExceptionHandler: " + ex.getMessage());
        ex.printStackTrace();
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(new MessageResponse(ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
                errors.put(error.getField(), error.getDefaultMessage()));
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(errors);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<MessageResponse> handleGenericException(Exception ex) {
        System.err.println("Internal error caught in GlobalExceptionHandler: " + ex.getMessage());
        ex.printStackTrace();
        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(new MessageResponse("An internal error occurred: " + ex.getMessage()));
    }

    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotWritableException.class)
    public void handleMessageNotWritableException(org.springframework.http.converter.HttpMessageNotWritableException ex, jakarta.servlet.http.HttpServletResponse response) throws java.io.IOException {
        System.err.println("HttpMessageNotWritableException caught: " + ex.getMessage());
        // If the response is already committed or content-type is fixed (like text/event-stream),
        // we might not be able to return a standard JSON response.
        if (!response.isCommitted()) {
            response.setStatus(HttpStatus.INTERNAL_SERVER_ERROR.value());
            response.setContentType("application/json");
            // Use a simple JSON string to avoid any further serialization issues
            response.getWriter().write("{\"message\":\"Error writing response: " + ex.getMessage().replace("\"", "'").replace("\n", " ") + "\"}");
        } else {
            System.err.println("Response already committed. Cannot send error details to client.");
        }
    }
}
