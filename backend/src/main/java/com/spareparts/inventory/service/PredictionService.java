package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Order;
import com.spareparts.inventory.entity.OrderItem;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.OrderRepository;
import com.spareparts.inventory.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;

@Service
public class PredictionService {
    private static final Logger log = LoggerFactory.getLogger(PredictionService.class);

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private AIService aiService;

    @Transactional(readOnly = true)
    public Map<String, Integer> predictDemand(List<Order> orders) {
        Map<String, Integer> totalDemand = new HashMap<>();
        Map<String, Integer> productOccurrence = new HashMap<>();

        for (Order order : orders) {
            for (OrderItem item : order.getItems()) {
                String productName = item.getProduct().getName();
                int qty = item.getQuantity();

                totalDemand.put(productName, totalDemand.getOrDefault(productName, 0) + qty);
                productOccurrence.put(productName, productOccurrence.getOrDefault(productName, 0) + 1);
            }
        }

        Map<String, Integer> prediction = new HashMap<>();
        for (String product : totalDemand.keySet()) {
            int total = totalDemand.get(product);
            int occurrences = productOccurrence.get(product);
            // Average daily demand based on 30 days data (simplified)
            int avgDemand = (int) Math.ceil((double) total / 30.0 * 7.0); // Predicted demand for next 7 days
            prediction.put(product, avgDemand);
        }

        return prediction;
    }

    @Transactional(readOnly = true)
    public List<String> getRestockSuggestions() {
        LocalDateTime thirtyDaysAgo = LocalDateTime.now().minusDays(30);
        List<Order> recentOrders = orderRepository.findLast30Days(thirtyDaysAgo);
        Map<String, Integer> predicted7DayDemand = predictDemand(recentOrders);

        List<Product> allProducts = productRepository.findByDeletedFalse();
        List<String> suggestions = new ArrayList<>();

        for (Product p : allProducts) {
            int currentStock = p.getStock();
            int predictedDemand = predicted7DayDemand.getOrDefault(p.getName(), 0);

            if (currentStock < predictedDemand) {
                suggestions.add(String.format("%s (Current Stock: %d, Predicted 7-day Demand: %d) -> Restock needed!", 
                        p.getName(), currentStock, predictedDemand));
            } else if (currentStock < predictedDemand * 1.5) {
                suggestions.add(String.format("%s (Current Stock: %d, Predicted 7-day Demand: %d) -> Stock getting low.", 
                        p.getName(), currentStock, predictedDemand));
            }
        }

        return suggestions;
    }

    @Scheduled(cron = "0 0 9 * * ?") // Every day at 9 AM
    public void runDailyAutoReorderCheck() {
        log.info("Starting daily auto-reorder check...");
        List<String> suggestions = getRestockSuggestions();
        if (!suggestions.isEmpty()) {
            String advice = getAIStockAdvice(suggestions);
            log.info("AI Reorder Advice: {}", advice);
            // Here you could send email/WhatsApp notifications
        }
    }

    public String getAIStockAdvice(List<String> suggestions) {
        if (suggestions == null || suggestions.isEmpty()) {
            return "Inventory levels are currently healthy across all items. No immediate restock actions required.";
        }
        
        String data = String.join("\n", suggestions);
        String prompt = String.format(
                "You are an expert inventory manager for Parts Mitra.\n" +
                "Analyze these low stock alerts and predicted demands:\n%s\n\n" +
                "Provide a professional recommendation on which items to reorder and in what priority.\n" +
                "Keep it concise and actionable using bullet points.",
                data
        );

        return aiService.askAI(prompt, "gemini", null);
    }

    @Transactional(readOnly = true)
    public String getAIBusinessInsights() {
        try {
            LocalDateTime thirtyDaysAgo = LocalDateTime.now().minusDays(30);
            List<Order> recentOrders = orderRepository.findLast30Days(thirtyDaysAgo);
            
            if (recentOrders.isEmpty()) {
                return "Not enough sales data in the last 30 days to generate business insights.";
            }

            List<Map<String, Object>> topSelling = orderRepository.findTopSellingProducts(PageRequest.of(0, 10));
            List<Map<String, Object>> monthlySales = orderRepository.getMonthlySales();
            List<String> restockAlerts = getRestockSuggestions();

            StringBuilder data = new StringBuilder();
            data.append("Monthly Sales Performance:\n");
            for (Map<String, Object> sale : monthlySales) {
                data.append("- ").append(sale.get("month")).append(": ₹").append(sale.get("total")).append("\n");
            }

            data.append("\nTop Selling Products:\n");
            for (Map<String, Object> product : topSelling) {
                data.append("- ").append(product.get("name")).append(": ").append(product.get("count")).append(" units\n");
            }

            data.append("\nLow Stock & Demand Prediction Alerts:\n");
            for (String alert : restockAlerts) {
                data.append("- ").append(alert).append("\n");
            }

            String prompt = String.format(
                "You are a senior business analyst for Parts Mitra, a leading auto spare parts distributor.\n" +
                "Based on the following 30-day performance data, provide 3-4 strategic business insights:\n\n" +
                "%s\n\n" +
                "Your analysis should include:\n" +
                "1. Revenue trends and growth opportunities.\n" +
                "2. Inventory optimization advice based on demand.\n" +
                "3. Customer behavior or popular category focus.\n" +
                "4. A clear 'Action Item' for the owner.\n\n" +
                "Format with professional headers and clear bullet points. Keep it highly strategic and data-driven.",
                data.toString()
            );

            return aiService.askAI(prompt, "gemini", null);
        } catch (Exception e) {
            log.error("Error generating AI business insights: {}", e.getMessage());
            return "Unable to generate business insights at this moment. Please try again later.";
        }
    }
}
