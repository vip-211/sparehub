
package com.spareparts.inventory.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginRequest {
    @NotBlank
    @JsonAlias({"email", "username"})
    private String identifier;

    @NotBlank
    private String password;
}
