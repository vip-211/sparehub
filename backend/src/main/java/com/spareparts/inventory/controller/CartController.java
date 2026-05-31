
package com.spareparts.inventory.controller;

import com.spareparts.inventory.dto.CartDto;
import com.spareparts.inventory.dto.CartItemDto;
import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.security.UserDetailsImpl;
import com.spareparts.inventory.service.CartService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/cart")
@CrossOrigin(origins = "*", maxAge = 3600)
public class CartController {

    @Autowired
    private CartService cartService;

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    public ResponseEntity<CartDto> getCart(Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        User user = userRepository.findById(userDetails.getId()).orElseThrow();
        CartDto cart = cartService.getCartByUser(user);
        return ResponseEntity.ok(cart);
    }

    @PutMapping
    public ResponseEntity<CartDto> updateCart(@RequestBody List<CartItemDto> items, Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        User user = userRepository.findById(userDetails.getId()).orElseThrow();
        CartDto updatedCart = cartService.updateCart(user, items);
        return ResponseEntity.ok(updatedCart);
    }

    @DeleteMapping
    public ResponseEntity<Void> clearCart(Authentication authentication) {
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        User user = userRepository.findById(userDetails.getId()).orElseThrow();
        cartService.clearCart(user);
        return ResponseEntity.noContent().build();
    }
}

