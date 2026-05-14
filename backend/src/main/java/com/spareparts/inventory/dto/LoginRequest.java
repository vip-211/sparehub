
package com.spareparts.inventory.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginRequest {
    @NotBlank
    private String identifier;

    @NotBlank
    private String password;
}
