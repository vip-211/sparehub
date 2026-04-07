package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

import java.util.Base64;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.transaction.annotation.Transactional;

@Service
public class AIService {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(AIService.class);

    @Value("${app.gemini.api.key:}")
    private String geminiApiKey;
    @Value("${app.openai.api.key:}")
    private String openaiApiKey;
    @Value("${app.openai.model:gpt-4o-mini}")
    private String openaiModel;

    @Autowired
    private ProductRepository productRepository;

    private static final String GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=";
    private static final String OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions";
    private static final String OPENAI_TRANSCRIBE_URL = "https://api.openai.com/v1/audio/transcriptions";

    private final RestTemplate restTemplate = new RestTemplate();

    @Transactional(readOnly = true)
    public String askAI(String prompt, String provider) {
        // Debug Log: Check if API keys are loaded (masked for security)
        log.info("AIService: Checking configuration... Gemini Key Present: {}, OpenAI Key Present: {}", 
                 (geminiApiKey != null && !geminiApiKey.isEmpty()), 
                 (openaiApiKey != null && !openaiApiKey.isEmpty()));

        try {
            // Smart Search: Check for relevant products based on prompt first
            List<String> tokens = List.of(prompt.split("\\W+"));
            String matchedContext = tokens.stream()
                    .filter(t -> t.length() > 2)
                    .flatMap(t -> productRepository.findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(t, t).stream())
                    .distinct()
                    .limit(10)
                    .map(p -> p.getName() + " (Part: " + p.getPartNumber() + ") • Price: ₹" + p.getSellingPrice() + " • Stock: " + p.getStock())
                    .collect(Collectors.joining(", "));

            String productContext = productRepository.findAll().stream()
                    .filter(p -> !p.isDeleted() && p.isEnabled())
                    .limit(20)
                    .map(p -> p.getName() + " (Part: " + p.getPartNumber() + ")")
                    .collect(Collectors.joining(", "));

            String fullContext = matchedContext.isEmpty() ? productContext : "Matching parts found: " + matchedContext + ". General sample: " + productContext;

            String systemPrompt = "You are an AI assistant for Parts Mitra, an auto spare parts inventory system. " +
                    "Contextual inventory data: " + fullContext + ". " +
                    "Guidelines: " +
                    "1. Prioritize 'Matching parts found' above for the user's query. " +
                    "2. If stock is 0, mention it's out of stock. " +
                    "3. If no matching parts are found, suggest searching by part number or photo. " +
                    "4. Be professional and concise.";

            String p = provider == null ? "" : provider.toLowerCase();
            if ("openai".equals(p)) {
                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);
                headers.setBearerAuth(openaiApiKey);

                Map<String, Object> req = new HashMap<>();
                req.put("model", openaiModel);
                List<Map<String, Object>> messages = List.of(
                        Map.of("role", "system", "content", systemPrompt),
                        Map.of("role", "user", "content", prompt)
                );
                req.put("messages", messages);

                HttpEntity<Map<String, Object>> entity = new HttpEntity<>(req, headers);
                Map<String, Object> response = restTemplate.postForObject(OPENAI_CHAT_URL, entity, Map.class);
                if (response != null && response.containsKey("choices")) {
                    List<Map<String, Object>> choices = (List<Map<String, Object>>) response.get("choices");
                    if (!choices.isEmpty()) {
                        Map<String, Object> first = choices.get(0);
                        Map<String, Object> msg = (Map<String, Object>) first.get("message");
                        Object content = msg != null ? msg.get("content") : null;
                        if (content != null) return content.toString();
                    }
                }
                return "I couldn't generate a response.";
            }

            if ("gemini".equals(p) || p.isEmpty()) {
                if (geminiApiKey == null || geminiApiKey.isEmpty()) {
                    if (openaiApiKey != null && !openaiApiKey.isEmpty()) {
                        // Fallback to OpenAI only if Gemini key missing and OpenAI available
                        HttpHeaders headers = new HttpHeaders();
                        headers.setContentType(MediaType.APPLICATION_JSON);
                        headers.setBearerAuth(openaiApiKey);

                        Map<String, Object> req = new HashMap<>();
                        req.put("model", openaiModel);
                        List<Map<String, Object>> messages = List.of(
                                Map.of("role", "system", "content", systemPrompt),
                                Map.of("role", "user", "content", prompt)
                        );
                        req.put("messages", messages);

                        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(req, headers);
                        Map<String, Object> response = restTemplate.postForObject(OPENAI_CHAT_URL, entity, Map.class);
                        if (response != null && response.containsKey("choices")) {
                            List<Map<String, Object>> choices = (List<Map<String, Object>>) response.get("choices");
                            if (!choices.isEmpty()) {
                                Map<String, Object> first = choices.get(0);
                                Map<String, Object> msg = (Map<String, Object>) first.get("message");
                                Object content = msg != null ? msg.get("content") : null;
                                if (content != null) return content.toString();
                            }
                        }
                        return "I couldn't generate a response.";
                    }
                    return "AI integration is not configured. Please set GEMINI_API_KEY.";
                }
                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);

                Map<String, Object> requestBody = new HashMap<>();
                Map<String, Object> content = new HashMap<>();
                Map<String, Object> part = new HashMap<>();
                String fullPrompt = systemPrompt + " User's question: " + prompt;
                part.put("text", fullPrompt);
                content.put("parts", Collections.singletonList(part));
                requestBody.put("contents", Collections.singletonList(content));

                HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
                Map<String, Object> response = restTemplate.postForObject(GEMINI_API_URL + geminiApiKey, entity, Map.class);
                if (response != null && response.containsKey("candidates")) {
                    List<Map<String, Object>> candidates = (List<Map<String, Object>>) response.get("candidates");
                    if (!candidates.isEmpty()) {
                        Map<String, Object> candidate = candidates.get(0);
                        Map<String, Object> contentRes = (Map<String, Object>) candidate.get("content");
                        if (contentRes != null && contentRes.containsKey("parts")) {
                            List<Map<String, Object>> partsRes = (List<Map<String, Object>>) contentRes.get("parts");
                            if (!partsRes.isEmpty()) {
                                Object t = partsRes.get(0).get("text");
                                if (t != null) return t.toString();
                            }
                        }
                    }
                }
                Object error = response != null ? response.get("error") : null;
                if (error != null) return "AI service error: " + error.toString();
                return "I couldn't generate a response.";
            }
            if ("local".equals(p) || ((openaiApiKey == null || openaiApiKey.isEmpty()) && (geminiApiKey == null || geminiApiKey.isEmpty()))) {
                String q = prompt == null ? "" : prompt.trim();
                if (q.isEmpty()) return "Please describe the part or question.";
                List<String> localTokens = List.of(q.split("\\W+"));
                List<Product> found = localTokens.stream()
                        .filter(t -> t.length() > 1)
                        .flatMap(t -> productRepository.findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(t, t).stream())
                        .distinct()
                        .limit(10)
                        .toList();
                if (!found.isEmpty()) {
                    String suggestions = found.stream()
                            .map(p2 -> p2.getName() + " (" + p2.getPartNumber() + ")")
                            .collect(Collectors.joining(", "));
                    return "Suggestions: " + suggestions;
                }
                return "I couldn't find matching products. Try specifying the part name or number.";
            }
            return "AI integration is not configured. Please set GEMINI_API_KEY or OPENAI_API_KEY.";
        } catch (Exception e) {
            return "AI service error: " + e.getMessage();
        }
    }

    @Transactional(readOnly = true)
    public String searchByPhoto(MultipartFile image, String provider) {
        try {
            String productContext = productRepository.findAll().stream()
                    .filter(p -> !p.isDeleted() && p.isEnabled())
                    .limit(30)
                    .map(p -> p.getName() + " (Part: " + p.getPartNumber() + ")")
                    .collect(Collectors.joining(", "));

            boolean useOpenAI = "openai".equalsIgnoreCase(provider) || (openaiApiKey != null && !openaiApiKey.isEmpty());
            if (useOpenAI) {
                String mime = image.getContentType() != null ? image.getContentType() : "image/jpeg";
                String dataUrl = "data:" + mime + ";base64," + Base64.getEncoder().encodeToString(image.getBytes());

                String systemPrompt = "You are a vision assistant for auto spare parts. Use the image to identify the part and suggest matching items from inventory: " + productContext + ".";

                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);
                headers.setBearerAuth(openaiApiKey);

                Map<String, Object> req = new HashMap<>();
                req.put("model", openaiModel);

                Map<String, Object> sysMsg = new HashMap<>();
                sysMsg.put("role", "system");
                sysMsg.put("content", systemPrompt);

                List<Map<String, Object>> content = List.of(
                        Map.of("type", "text", "text", "Identify the spare part from this image and provide name and likely part number."),
                        Map.of("type", "input_image", "image_url", dataUrl)
                );
                Map<String, Object> userMsg = new HashMap<>();
                userMsg.put("role", "user");
                userMsg.put("content", content);

                req.put("messages", List.of(sysMsg, userMsg));

                HttpEntity<Map<String, Object>> entity = new HttpEntity<>(req, headers);
                Map<String, Object> response = restTemplate.postForObject(OPENAI_CHAT_URL, entity, Map.class);
                if (response != null && response.containsKey("choices")) {
                    List<Map<String, Object>> choices = (List<Map<String, Object>>) response.get("choices");
                    if (!choices.isEmpty()) {
                        Map<String, Object> first = choices.get(0);
                        Map<String, Object> msg = (Map<String, Object>) first.get("message");
                        Object contentResp = msg != null ? msg.get("content") : null;
                        if (contentResp != null) return contentResp.toString();
                    }
                }
                return "I couldn't analyze the image.";
            } else if (geminiApiKey != null && !geminiApiKey.isEmpty()) {
                String mime = image.getContentType() != null ? image.getContentType() : "image/jpeg";
                String base64 = Base64.getEncoder().encodeToString(image.getBytes());

                String fullPrompt = "You are a vision assistant for auto spare parts. Identify the part from this image and provide name and likely part number. Use our inventory context: "
                        + productContext + ". Keep it concise.";

                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);

                Map<String, Object> inlineData = new HashMap<>();
                inlineData.put("mime_type", mime);
                inlineData.put("data", base64);

                Map<String, Object> parts = new HashMap<>();
                parts.put("parts", List.of(
                        Map.of("text", fullPrompt),
                        Map.of("inline_data", inlineData)
                ));

                Map<String, Object> requestBody = new HashMap<>();
                requestBody.put("contents", List.of(parts));

                HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
                Map<String, Object> response = restTemplate.postForObject(GEMINI_API_URL + geminiApiKey, entity, Map.class);
                if (response != null && response.containsKey("candidates")) {
                    List<Map<String, Object>> candidates = (List<Map<String, Object>>) response.get("candidates");
                    if (!candidates.isEmpty()) {
                        Map<String, Object> candidate = candidates.get(0);
                        Map<String, Object> contentRes = (Map<String, Object>) candidate.get("content");
                        if (contentRes != null && contentRes.containsKey("parts")) {
                            List<Map<String, Object>> partsRes = (List<Map<String, Object>>) contentRes.get("parts");
                            if (!partsRes.isEmpty()) {
                                Object t = partsRes.get(0).get("text");
                                if (t != null) return t.toString();
                            }
                        }
                    }
                }
                Object error = response != null ? response.get("error") : null;
                if (error != null) return "AI service error: " + error.toString();
                return "I couldn't analyze the image.";
            }
            return "AI integration is not configured. Please set OPENAI_API_KEY.";
        } catch (Exception e) {
            return "AI service error: " + e.getMessage();
        }
    }

    @Transactional(readOnly = true)
    public String searchByVoice(MultipartFile audio, String provider) {
        try {
            boolean useOpenAI = "openai".equalsIgnoreCase(provider) || (openaiApiKey != null && !openaiApiKey.isEmpty());
            if (useOpenAI) {
                HttpHeaders headers = new HttpHeaders();
                headers.setBearerAuth(openaiApiKey);
                headers.setContentType(MediaType.MULTIPART_FORM_DATA);

                ByteArrayResource audioRes = new ByteArrayResource(audio.getBytes()) {
                    @Override
                    public String getFilename() {
                        return audio.getOriginalFilename() != null ? audio.getOriginalFilename() : "audio.wav";
                    }
                };

                MultiValueMap<String, Object> form = new LinkedMultiValueMap<>();
                form.add("file", audioRes);
                form.add("model", "whisper-1");

                HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(form, headers);
                Map<String, Object> transcribe = restTemplate.postForObject(OPENAI_TRANSCRIBE_URL, entity, Map.class);
                String text = transcribe != null ? (String) transcribe.get("text") : null;
                if (text == null || text.isEmpty()) {
                    return "I couldn't transcribe the audio.";
                }

                List<Product> matches = productRepository.findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(text, text);
                String matched = matches.stream()
                        .limit(10)
                        .map(p -> p.getName() + " (" + p.getPartNumber() + ")")
                        .collect(Collectors.joining(", "));
                if (matched.isEmpty()) {
                    return "No matching products found for: " + text;
                }
                return "Query: " + text + ". Matches: " + matched;
            } else if (geminiApiKey != null && !geminiApiKey.isEmpty()) {
                String mime = audio.getContentType() != null ? audio.getContentType() : "audio/wav";
                String base64 = Base64.getEncoder().encodeToString(audio.getBytes());

                String prompt = "Transcribe the following audio into a concise text query to search auto spare parts. Return only the query text.";

                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);

                Map<String, Object> inlineData = new HashMap<>();
                inlineData.put("mime_type", mime);
                inlineData.put("data", base64);

                Map<String, Object> parts = new HashMap<>();
                parts.put("parts", List.of(
                        Map.of("text", prompt),
                        Map.of("inline_data", inlineData)
                ));

                Map<String, Object> requestBody = new HashMap<>();
                requestBody.put("contents", List.of(parts));

                HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
                Map<String, Object> response = restTemplate.postForObject(GEMINI_API_URL + geminiApiKey, entity, Map.class);
                String text = null;
                if (response != null && response.containsKey("candidates")) {
                    List<Map<String, Object>> candidates = (List<Map<String, Object>>) response.get("candidates");
                    if (!candidates.isEmpty()) {
                        Map<String, Object> candidate = candidates.get(0);
                        Map<String, Object> contentRes = (Map<String, Object>) candidate.get("content");
                        if (contentRes != null && contentRes.containsKey("parts")) {
                            List<Map<String, Object>> partsRes = (List<Map<String, Object>>) contentRes.get("parts");
                            if (!partsRes.isEmpty()) {
                                Object t = partsRes.get(0).get("text");
                                if (t != null) text = t.toString();
                            }
                        }
                    }
                }
                if (text == null || text.isEmpty()) {
                    Object error = response != null ? response.get("error") : null;
                    if (error != null) return "AI service error: " + error.toString();
                    return "I couldn't transcribe the audio.";
                }
                List<Product> matches = productRepository.findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(text, text);
                String matched = matches.stream()
                        .limit(10)
                        .map(p -> p.getName() + " (" + p.getPartNumber() + ")")
                        .collect(Collectors.joining(", "));
                if (matched.isEmpty()) {
                    return "No matching products found for: " + text;
                }
                return "Query: " + text + ". Matches: " + matched;
            }
            return "AI integration is not configured. Please set OPENAI_API_KEY.";
        } catch (Exception e) {
            return "AI service error: " + e.getMessage();
        }
    }
}
