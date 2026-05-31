
package com.spareparts.inventory.service;

import com.spareparts.inventory.dto.CartDto;
import com.spareparts.inventory.dto.CartItemDto;
import com.spareparts.inventory.entity.*;
import static com.spareparts.inventory.entity.RoleName.*;
import com.spareparts.inventory.repository.CartRepository;
import com.spareparts.inventory.repository.ProductRepository;
import com.spareparts.inventory.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@Slf4j
public class CartService {

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ProductRepository productRepository;

    public CartDto getCartByUser(User user) {
        Cart cart = cartRepository.findByUser(user).orElseGet(() -> {
            Cart newCart = new Cart();
            newCart.setUser(user);
            newCart.setItems(new ArrayList<>());
            return cartRepository.save(newCart);
        });
        return convertToDto(cart, user);
    }

    @Transactional
    public CartDto updateCart(User user, List<CartItemDto> itemDtos) {
        Cart cart = cartRepository.findByUser(user).orElseGet(() -> {
            Cart newCart = new Cart();
            newCart.setUser(user);
            newCart.setItems(new ArrayList<>());
            return cartRepository.save(newCart);
        });

        cart.getItems().clear();

        for (CartItemDto dto : itemDtos) {
            Product product = productRepository.findById(dto.getProductId())
                    .orElseThrow(() -> new RuntimeException("Product not found: " + dto.getProductId()));

            CartItem cartItem = new CartItem();
            cartItem.setCart(cart);
            cartItem.setProduct(product);
            cartItem.setQuantity(dto.getQuantity() != null ? dto.getQuantity() : 1);
            cartItem.setIsLocked(dto.getIsLocked() != null ? dto.getIsLocked() : false);
            cartItem.setBannerId(dto.getBannerId());
            cartItem.setOfferId(dto.getOfferId());

            cart.getItems().add(cartItem);
        }

        Cart savedCart = cartRepository.save(cart);
        return convertToDto(savedCart, user);
    }

    @Transactional
    public void clearCart(User user) {
        Cart cart = cartRepository.findByUser(user).orElse(null);
        if (cart != null) {
            cart.getItems().clear();
            cartRepository.save(cart);
        }
    }

    private CartDto convertToDto(Cart cart, User user) {
        CartDto dto = new CartDto();
        dto.setId(cart.getId());

        List<CartItemDto> itemDtos = cart.getItems().stream().map(item -> {
            CartItemDto itemDto = new CartItemDto();
            itemDto.setId(item.getId());
            itemDto.setProductId(item.getProduct().getId());
            itemDto.setName(item.getProduct().getName());
            itemDto.setPartNumber(item.getProduct().getPartNumber());
            itemDto.setImage(getProductImage(item.getProduct()));
            itemDto.setPrice(getPriceForUser(item.getProduct(), user));
            itemDto.setQuantity(item.getQuantity());
            itemDto.setIsLocked(item.getIsLocked());
            itemDto.setBannerId(item.getBannerId());
            itemDto.setOfferId(item.getOfferId());
            return itemDto;
        }).collect(Collectors.toList());

        dto.setItems(itemDtos);
        return dto;
    }

    private String getProductImage(Product product) {
        if (product.getImagePath() != null && !product.getImagePath().isEmpty()) {
            return product.getImagePath();
        }
        if (product.getImageLink() != null && !product.getImageLink().isEmpty()) {
            return product.getImageLink();
        }
        if (product.getImages() != null && !product.getImages().isEmpty()) {
            return product.getImages().get(0).getImageUrl();
        }
        return null;
    }

    private Double getPriceForUser(Product product, User user) {
        BigDecimal price;
        if (user.getRole() == null || user.getRole().getName() == null) {
            price = product.getSellingPrice();
        } else {
            switch (user.getRole().getName()) {
                case ROLE_WHOLESALER:
                    price = product.getWholesalerPrice();
                    break;
                case ROLE_RETAILER:
                    price = product.getRetailerPrice();
                    break;
                case ROLE_MECHANIC:
                default:
                    price = product.getMechanicPrice();
                    break;
            }
        }
        return price != null ? price.doubleValue() : 0.0;
    }
}

