package com.spareparts.inventory.observer;

import com.spareparts.inventory.entity.Product;
import java.util.ArrayList;
import java.util.List;

public abstract class ProductSubject {
    private List<ProductObserver> observers = new ArrayList<>();

    public void addObserver(ProductObserver observer) {
        observers.add(observer);
    }

    public void removeObserver(ProductObserver observer) {
        observers.remove(observer);
    }

    protected void notifyObservers(Product product) {
        for (ProductObserver observer : observers) {
            observer.update(product);
        }
    }
}
