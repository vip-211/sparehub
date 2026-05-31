
package com.spareparts.inventory.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
@Slf4j
public class NotificationTemplateService {

    private static final Random RANDOM = new Random();

    public enum Language {
        ENGLISH,
        HINDI,
        MARATHI
    }

    public enum NotificationType {
        CART_REMINDER,
        PREVIOUS_ORDER_REMINDER
    }

    public record NotificationMessage(String title, String body) {}

    private static final Map<Language, List<NotificationMessage>> CART_TEMPLATES = new HashMap<>();
    private static final Map<Language, List<NotificationMessage>> ORDER_TEMPLATES = new HashMap<>();

    static {
        // English Templates
        CART_TEMPLATES.put(Language.ENGLISH, Arrays.asList(
                new NotificationMessage("Hey, your cart is waiting! 🛒", "You left some items in your cart. Don't let them gather dust - check out now!"),
                new NotificationMessage("Psst... your cart misses you! 😏", "Remember those spare parts you added? They're still waiting to be yours!"),
                new NotificationMessage("Your cart is feeling lonely! 😢", "Give your cart some love - complete your purchase today!"),
                new NotificationMessage("Don't make your cart wait! ⏰", "The early bird gets the worm (and the spare parts). Order now!"),
                new NotificationMessage("Your cart has needs! 💰", "Time to turn that wishlist into an order. You know you want to!"),
                new NotificationMessage("Hurry! Your items are still in the cart! 🏃", "Stock is limited - grab those parts before they're gone!"),
                new NotificationMessage("What's in your cart? Let's find out! 🎁", "Click here to see your waiting items and complete your order!")
        ));

        ORDER_TEMPLATES.put(Language.ENGLISH, Arrays.asList(
                new NotificationMessage("Time for a restock? 📦", "You ordered these parts before. Maybe it's time to get them again!"),
                new NotificationMessage("Your past order is calling! 📞", "Remember those spare parts you loved? They're still available!"),
                new NotificationMessage("We miss your orders! 😊", "How about a repeat of your last purchase? Your vehicle will thank you!"),
                new NotificationMessage("Restock alert! 🔔", "Your previous order items are ready for a comeback. Check them out!"),
                new NotificationMessage("Your favorites are waiting! ⭐", "You ordered these before. Want to make them yours again?"),
                new NotificationMessage("Back by popular demand (yours)! 🔥", "Time to reorder those trusty spare parts you rely on!"),
                new NotificationMessage("Your vehicle might need a check-up! 🔧", "Why not grab those same parts again? They worked great last time!")
        ));

        // Hindi Templates
        CART_TEMPLATES.put(Language.HINDI, Arrays.asList(
                new NotificationMessage("अरे, आपका कार्ट इंतजार कर रहा है! 🛒", "आपने अपने कार्ट में कुछ आइटम छोड़े हैं। उन्हें धूल न जमने दें - अभी चेकआउट करें!"),
                new NotificationMessage("सुनो... आपका कार्ट आपको याद कर रहा है! 😏", "उन स्पेयर पार्ट्स को याद है जो आपने जोड़े थे? वे अभी भी आपके होने का इंतजार कर रहे हैं!"),
                new NotificationMessage("आपका कार्ट अकेला महसूस कर रहा है! 😢", "अपने कार्ट को कुछ प्यार दें - आज ही अपनी खरीदारी पूरी करें!"),
                new NotificationMessage("अपने कार्ट को इंतजार न करें! ⏰", "जो जल्दी करता है वही पाता है (और स्पेयर पार्ट्स भी)। अभी ऑर्डर करें!"),
                new NotificationMessage("आपके कार्ट की कुछ जरूरतें हैं! 💰", "उस विशलिस्ट को ऑर्डर में बदलने का समय है। आप जानते हैं कि आप चाहते हैं!"),
                new NotificationMessage("जल्दी करें! आपके आइटम अभी भी कार्ट में हैं! 🏃", "स्टॉक सीमित है - वे पार्ट्स गायब होने से पहले उन्हें पकड़ लें!"),
                new NotificationMessage("आपके कार्ट में क्या है? चलिए जानते हैं! 🎁", "अपने इंतजार कर रहे आइटम देखने और ऑर्डर पूरा करने के लिए यहां क्लिक करें!")
        ));

        ORDER_TEMPLATES.put(Language.HINDI, Arrays.asList(
                new NotificationMessage("रीस्टॉक का समय है? 📦", "आपने पहले भी ये पार्ट्स ऑर्डर की थीं। शायद उन्हें फिर से पाने का समय है!"),
                new NotificationMessage("आपका पिछला ऑर्डर बुला रहा है! 📞", "उन स्पेयर पार्ट्स को याद है जो आपने पसंद की थीं? वे अभी भी उपलब्ध हैं!"),
                new NotificationMessage("हमें आपके ऑर्डर याद आते हैं! 😊", "अपनी आखिरी खरीदारी को दोहराने का क्यों न? आपका वाहन आपको धन्यवाद देगा!"),
                new NotificationMessage("रीस्टॉक अलर्ट! 🔔", "आपके पिछले ऑर्डर के आइटम वापस आने के लिए तैयार हैं। उन्हें चेक करें!"),
                new NotificationMessage("आपकी पसंदीदा चीजें इंतजार कर रही हैं! ⭐", "आपने ये पहले ऑर्डर किया था। क्या आप उन्हें फिर से अपनाना चाहते हैं?"),
                new NotificationMessage("लोकप्रिय मांग पर वापस (आपकी)! 🔥", "उन भरोसेमंद स्पेयर पार्ट्स को फिर से ऑर्डर करने का समय जिन पर आप भरोसा करते हैं!"),
                new NotificationMessage("आपके वाहन को चेक-अप की जरूरत हो सकती है! 🔧", "उन्हीं पार्ट्स को फिर से क्यों न लें? पिछली बार वे बहुत अच्छे काम आई थीं!")
        ));

        // Marathi Templates
        CART_TEMPLATES.put(Language.MARATHI, Arrays.asList(
                new NotificationMessage("अरे, तुझा कार्ट वाट पाहत आहे! 🛒", "तुम्ही तुमच्या कार्टमध्ये काही आयटम सोडले आहेत. त्यांना धूळ जमू देऊ नका - आत्ताच चेकआउट करा!"),
                new NotificationMessage("सुनो... तुझा कार्ट तुला आठवत आहे! 😏", "तुम्ही ज्या स्पेअर पार्ट्स जोडल्या होत्या ती आठवत आहेत? ती अजूनही तुमच्या होण्याची वाट पाहत आहेत!"),
                new NotificationMessage("तुझा कार्ट एकटा वाटत आहे! 😢", "तुमच्या कार्टला थोडे प्रेम द्या - आजच तुमची खरेदी पूर्ण करा!"),
                new NotificationMessage("तुमच्या कार्टला वाट बसू देऊ नका! ⏰", "जो लवकर करतो तोच मिळवतो (आणि स्पेअर पार्ट्स देखील). आत्ताच ऑर्डर करा!"),
                new NotificationMessage("तुमच्या कार्टच्या काही गरजा आहेत! 💰", "त्या विशलिस्टला ऑर्डरमध्ये बदलण्याची वेळ आली आहे. तुला माहीतच आहे की तू हवेस!"),
                new NotificationMessage("लवकर करा! तुमचे आयटम अजूनही कार्टमध्ये आहेत! 🏃", "स्टॉक मर्यादित आहे - ते पार्ट्स निघून जाण्यापूर्वी ते पकडा!"),
                new NotificationMessage("तुमच्या कार्टमध्ये काय आहे? चला जाणून घेऊ! 🎁", "तुमची वाट पाहत असलेली आयटम पाहण्यासाठी आणि ऑर्डर पूर्ण करण्यासाठी येथे क्लिक करा!")
        ));

        ORDER_TEMPLATES.put(Language.MARATHI, Arrays.asList(
                new NotificationMessage("रीस्टॉक करण्याची वेळ आली आहे? 📦", "तुम्ही या पार्ट्स पूर्वी ऑर्डर केल्या होत्या. कदाचित त्यांना पुन्हा मिळवण्याची वेळ आली आहे!"),
                new NotificationMessage("तुमचा मागील ऑर्डर ओरडत आहे! 📞", "तुम्हाला आवडणार्‍या त्या स्पेअर पार्ट्स आठवत आहेत? ती अजूनही उपलब्ध आहेत!"),
                new NotificationMessage("आम्हाला तुमचे ऑर्डर आठवतात! 😊", "तुमची शेवटची खरेदी पुन्हा करण्याचा विचार का करू नका? तुमचे वाहन तुमचे आभारी होईल!"),
                new NotificationMessage("रीस्टॉक अलर्ट! 🔔", "तुमच्या मागील ऑर्डरची आयटम परत येण्यासाठी तयार आहेत. ते तपासा!"),
                new NotificationMessage("तुमची आवडत्या गोष्टी वाट पाहत आहेत! ⭐", "तुम्ही हे पूर्वी ऑर्डर केले होते. तुम्हाला ते पुन्हा मिळवायचे आहेत का?"),
                new NotificationMessage("लोकप्रिय मागणीने परत (तुमची)! 🔥", "तुम्ही ज्या विश्वासार्ह स्पेअर पार्ट्सवर अवलंबून असता ते पुन्हा ऑर्डर करण्याची वेळ!"),
                new NotificationMessage("तुमच्या वाहनाला चेक-अपची गरज भासते! 🔧", "त्याच पार्ट्स पुन्हा का न घेता? मागच्या वेळी ते खूप छान काम आले होते!")
        ));
    }

    public NotificationMessage getRandomMessage(NotificationType type, Language language) {
        Map<Language, List<NotificationMessage>> templates = type == NotificationType.CART_REMINDER ? CART_TEMPLATES : ORDER_TEMPLATES;
        List<NotificationMessage> messages = templates.getOrDefault(language, CART_TEMPLATES.get(Language.ENGLISH));
        return messages.get(RANDOM.nextInt(messages.size()));
    }

    public Language getRandomLanguage() {
        Language[] languages = Language.values();
        return languages[RANDOM.nextInt(languages.length)];
    }
}

