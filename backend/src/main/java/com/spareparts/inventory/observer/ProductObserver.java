package com.spareparts.inventory.observer;

import com.spareparts.inventory.entity.Product;

public interface ProductObserver {
    void update(Product product);
    void sendOfferNotification(Product product);
    String getObserverName();
}
