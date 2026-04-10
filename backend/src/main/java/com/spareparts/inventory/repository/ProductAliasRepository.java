package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.ProductAlias;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductAliasRepository extends JpaRepository<ProductAlias, Long> {
    List<ProductAlias> findByProductId(Long productId);
    void deleteByProductId(Long productId);
}
