package com.spareparts.inventory.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.ProductRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.UserRepository;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class AgentService {
    private static final Logger log = LoggerFactory.getLogger(AgentService.class);
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    private AIService aiService;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private OrderService orderService;

    @Autowired
    private PredictionService predictionService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private FcmService fcmService;

    @Transactional
    public String processQuery(String userQuery, String provider, Long userId) {
        // Step 0: Get User Role and Language
        String role = "GUEST";
        String userName = "A user";
        if (userId != null) {
            User user = userRepository.findById(userId).orElse(null);
            if (user != null) {
                userName = user.getName() != null ? user.getName() : "User " + userId;
                if (user.getRole() != null) {
                    role = user.getRole().getName().name().replace("ROLE_", "");
                }
            }
        }
        String language = detectLanguage(userQuery);

        // Step 0.5: Handle "Need Assistance"
        String queryLower = userQuery.toLowerCase();
        if (queryLower.contains("need assistance") || queryLower.contains("help support") || 
            queryLower.contains("मदद चाहिए") || queryLower.contains("सहायता") || 
            queryLower.contains("मदत हवी")) {
            
            String adminMsg = String.format("%s needs assistance with the AI chatbot. Query: \"%s\"", userName, userQuery);
            fcmService.sendToAdminAndSuperManager("User Needs Assistance", adminMsg, null);
            
            if (language.equals("Hindi")) {
                return "मैंने एडमिन को सूचित कर दिया है। वे जल्द ही आपसे संपर्क करेंगे। आपकी क्या सहायता कर सकता हूँ?";
            } else if (language.equals("Marathi")) {
                return "मी ॲडमिनला सूचित केले आहे. ते लवकरच तुमच्याशी संपर्क साधतील. मी तुम्हाला कशी मदत करू शकतो?";
            }
            return "I have notified the admin. They will get back to you shortly. How else can I assist you?";
        }

        // Step 1: Detect action using AI
        String actionPrompt = String.format(
                "You are a specialized action-detector for a spare parts shop assistant.\n" +
                "Role: %s\n" +
                "Language: %s\n" +
                "Convert the user's query into a JSON object.\n" +
                "Actions available:\n" +
                "1. search_product: If the user is looking for a part or checking availability.\n" +
                "2. create_invoice: If the user wants to buy, order, create a bill, or invoice for items.\n" +
                "3. stock_prediction: If the user asks about what to restock, low stock items, or future demand.\n" +
                "4. general_query: For anything else (greetings, general help, maintenance advice).\n\n" +
                "Return ONLY a JSON object in this format:\n" +
                "{\n" +
                "  \"action\": \"search_product\" | \"create_invoice\" | \"stock_prediction\" | \"general_query\",\n" +
                "  \"product\": \"name of the product if mentioned, else null\",\n" +
                "  \"quantity\": number if mentioned, else 1\n" +
                "}\n\n" +
                "User Query: %s", role, language, userQuery);

        String aiResponse = aiService.askAI(actionPrompt, provider, null); // Call AI without history for action detection

        try {
            // Step 2: Parse AI's decision
            String jsonStr = extractJson(aiResponse);
            
            // Check if it's actually JSON before trying to parse
            if (jsonStr.trim().startsWith("{") && jsonStr.trim().endsWith("}")) {
                JsonNode node = objectMapper.readTree(jsonStr);
                String action = node.has("action") ? node.get("action").asText() : "general_query";
                String product = node.has("product") && !node.get("product").isNull() ? node.get("product").asText() : null;
                int quantity = node.has("quantity") ? node.get("quantity").asInt() : 1;

                log.info("AgentService: Role: {}, Lang: {}, Action: {}, Product: {}, Qty: {}", role, language, action, product, quantity);

                // Step 2.5: Role-based restriction
                if (role.equalsIgnoreCase("MECHANIC") && action.equals("delete_product")) {
                    return language.equals("Hindi") ? "❌ आपके पास यह कार्य करने की अनुमति नहीं है।" : "❌ You do not have permission to perform this action.";
                }

                // Step 3: Execute Business Logic
                switch (action) {
                    case "search_product":
                        if (product != null) {
                            List<Product> matches = productRepository.findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(product, product);
                            if (!matches.isEmpty()) {
                                String results = matches.stream()
                                        .limit(5)
                                        .map(p -> "• " + p.getName() + " (" + p.getPartNumber() + ") - ₹" + p.getSellingPrice() + " (Stock: " + p.getStock() + ")")
                                        .collect(Collectors.joining("\n"));
                                
                                return language.equals("Hindi") 
                                        ? "मुझे आपके लिए ये पुर्जे मिले हैं:\n" + results 
                                        : (language.equals("Marathi") ? "मला तुमच्यासाठी हे सुटे भाग सापडले आहेत:\n" + results : "I found these matching parts for you:\n" + results);
                            }
                        }
                        break;

                    case "create_invoice":
                        if (product != null) {
                            List<Product> matches = productRepository.findByNameContainingIgnoreCaseOrPartNumberContainingIgnoreCase(product, product);
                            if (!matches.isEmpty()) {
                                Product p = matches.get(0);
                                if (language.equals("Hindi")) {
                                    return String.format("मैं आपके लिए %d x %s का बिल बनाने में मदद कर सकता हूँ।\nमैंने पुर्जे की पहचान की है: %s (₹%.2f)।\nकृपया आगे बढ़ने के लिए इस आइटम को अपनी कार्ट में जोड़ें।", 
                                            quantity, p.getName(), p.getName(), p.getSellingPrice());
                                } else if (language.equals("Marathi")) {
                                    return String.format("मी तुम्हाला %d x %s चे बिल तयार करण्यास मदत करू शकतो.\nमी भाग ओळखला आहे: %s (₹%.2f).\nकृपया पुढे जाण्यासाठी ही वस्तू तुमच्या कार्टमध्ये जोडा.", 
                                            quantity, p.getName(), p.getName(), p.getSellingPrice());
                                }
                                return String.format("I can help you create an invoice for %d x %s.\nI've identified the part as: %s (₹%.2f).\nPlease add this item to your cart to proceed.", 
                                        quantity, p.getName(), p.getName(), p.getSellingPrice());
                            }
                            return language.equals("Hindi") ? "मुझे बिल बनाने के लिए सटीक पुर्जा '" + product + "' नहीं मिला।" : "I couldn't find the exact product '" + product + "' to create an invoice.";
                        }
                        return language.equals("Hindi") ? "आप किस उत्पाद के लिए बिल बनाना चाहेंगे?" : "What product would you like to create an invoice for?";

                    case "stock_prediction":
                        if (!role.equalsIgnoreCase("ADMIN") && !role.equalsIgnoreCase("SUPER_MANAGER")) {
                            return language.equals("Hindi") ? "❌ आपके पास स्टॉक भविष्यवाणी देखने की अनुमति नहीं है।" : "❌ You do not have permission to view stock predictions.";
                        }
                        List<String> stockAdvice = predictionService.getRestockSuggestions();
                        if (stockAdvice.isEmpty()) {
                            return language.equals("Hindi") ? "✅ स्टॉक लेवल अभी ठीक लग रहे हैं।" : "✅ All stock levels look good for now.";
                        }
                        String adviceStr = String.join("\n", stockAdvice);
                        String stockPrompt = String.format("Language: %s\nStock Data: %s\nGive clear, concise restock advice in %s.", language, adviceStr, language);
                        return aiService.askAI(stockPrompt, provider, null);

                    default:
                        break;
                }
            } else {
                log.warn("AgentService: AI Response was not valid JSON, defaulting to general query. Response: {}", aiResponse);
            }
        } catch (Exception e) {
            log.error("AgentService: Error parsing AI action JSON: {}. AI Response was: {}", e.getMessage(), aiResponse);
        }

        // Default: Let the standard conversational AIService handle it
        String conversationalPrompt = String.format("Role: %s\nLanguage: %s\nUser Query: %s\nPlease respond ONLY in %s.", 
                role, language, userQuery, language);
        return aiService.askAI(conversationalPrompt, provider, userId);
    }

    private String detectLanguage(String text) {
        if (text == null) return "English";
        if (text.matches(".*[\\u0900-\\u097F].*")) {
            // Hindi and Marathi use Devanagari. Simple check for common Marathi words.
            if (text.contains("का") || text.contains("आहे") || text.contains("नाही") || text.contains("करा")) {
                return "Marathi";
            }
            return "Hindi";
        }
        return "English";
    }

    private String extractJson(String aiResponse) {
        String jsonStr = aiResponse;
        if (jsonStr.contains("```json")) {
            jsonStr = jsonStr.substring(jsonStr.indexOf("```json") + 7, jsonStr.lastIndexOf("```")).trim();
        } else if (jsonStr.contains("```")) {
            jsonStr = jsonStr.substring(jsonStr.indexOf("```") + 3, jsonStr.lastIndexOf("```")).trim();
        }
        return jsonStr;
    }
}
