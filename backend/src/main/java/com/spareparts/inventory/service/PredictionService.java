package com.spareparts.inventory.service;

import com.spareparts.inventory.entity.Order;
import com.spareparts.inventory.entity.OrderItem;
import com.spareparts.inventory.entity.Product;
import com.spareparts.inventory.repository.OrderRepository;
import com.spareparts.inventory.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
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
        String data = String.join("\n", suggestions);
        String prompt = String.format(
                "You are an expert inventory manager for Parts Mitra.\n" +
                "Analyze these low stock alerts and predicted demands:\n%s\n\n" +
                "Provide a professional recommendation on which items to reorder and in what priority.\n" +
                "Keep it concise and actionable.", data);
        
        return aiService.askAI(prompt, "gemini", null);
    }
}
