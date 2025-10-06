package pe.com.backend.demo.repositories;

import org.springframework.data.jpa.repository.JpaRepository;

import pe.com.backend.demo.entities.Color;

public interface ColorRepository extends JpaRepository<Color, Integer> {
}
