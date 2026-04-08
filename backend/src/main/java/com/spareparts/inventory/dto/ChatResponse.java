package com.spareparts.inventory.dto;

import lombok.Data;
import java.util.List;

@Data
public class ChatResponse {
    private String message;
    private List<String> quickReplies;
}
