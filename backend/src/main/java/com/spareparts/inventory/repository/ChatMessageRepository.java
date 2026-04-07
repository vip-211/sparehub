package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.ChatMessage;
import com.spareparts.inventory.entity.User;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findByUserOrderByCreatedAtDesc(User user, Pageable pageable);
}
