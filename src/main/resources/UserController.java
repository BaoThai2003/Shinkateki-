package com.shinkatenki.controller;

import com.shinkatenki.entity.User;
import com.shinkatenki.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/users")
@CrossOrigin
public class UserController {

    private final UserRepository userRepository;

    public UserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @GetMapping
    public List<User> getAll() {
        return userRepository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<User> getById(@PathVariable Long id) {
        return userRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<?> create(@Valid @RequestBody User user, BindingResult bindingResult) {
        if (bindingResult.hasErrors()) {
            String errors = bindingResult.getFieldErrors().stream()
                    .map(e -> e.getField() + ": " + e.getDefaultMessage())
                    .collect(Collectors.joining(", "));
            return ResponseEntity.badRequest().body("Validation failed: " + errors);
        }
        try {
            if (userRepository.existsByUsername(user.getUsername())) {
                return ResponseEntity.badRequest().body("Username already exists");
            }
            if (userRepository.existsByEmail(user.getEmail())) {
                return ResponseEntity.badRequest().body("Email already exists");
            }
            User saved = userRepository.save(user);
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (DataIntegrityViolationException e) {
            return ResponseEntity.badRequest().body("Username or email already exists");
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @Valid @RequestBody User user, BindingResult bindingResult) {
        if (bindingResult.hasErrors()) {
            String errors = bindingResult.getFieldErrors().stream()
                    .map(e -> e.getField() + ": " + e.getDefaultMessage())
                    .collect(Collectors.joining(", "));
            return ResponseEntity.badRequest().body("Validation failed: " + errors);
        }
        return userRepository.findById(id).map(existing -> {
            try {
                // Check if new username is already taken by another user
                if (!existing.getUsername().equals(user.getUsername()) && userRepository.existsByUsername(user.getUsername())) {
                    return ResponseEntity.badRequest().body("Username already taken");
                }
                // Check if new email is already taken by another user
                if (!existing.getEmail().equals(user.getEmail()) && userRepository.existsByEmail(user.getEmail())) {
                    return ResponseEntity.badRequest().body("Email already taken");
                }
                existing.setUsername(user.getUsername());
                existing.setEmail(user.getEmail());
                if (user.getPassword() != null && !user.getPassword().isEmpty()) {
                    existing.setPassword(user.getPassword());
                }
                User updated = userRepository.save(existing);
                return ResponseEntity.ok(updated);
            } catch (DataIntegrityViolationException e) {
                return ResponseEntity.badRequest().body("Username or email already exists");
            }
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        return userRepository.findById(id).map(u -> {
            userRepository.deleteById(id);
            return ResponseEntity.noContent().<Void>build();
        }).orElse(ResponseEntity.notFound().build());
    }
}