package pe.com.backend.demo.controllers;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import pe.com.backend.demo.entities.Color;
import pe.com.backend.demo.repositories.ColorRepository;
import java.net.URI;
import java.util.List;

@Tag(name = "Colors", description = "CRUD de colores")
@RestController
@RequestMapping("/api/colors")
public class ColorController {

  private final ColorRepository repository;

  public ColorController(ColorRepository repository) {
    this.repository = repository;
  }

  @Operation(summary = "Listar todos los colores")
  @GetMapping
  public List<Color> findAll() {
    return repository.findAll();
  }

  @Operation(summary = "Obtener color por id")
  @GetMapping("/{id}")
  public ResponseEntity<Color> findById(@PathVariable Integer id) {
    return repository.findById(id)
        .map(ResponseEntity::ok)
        .orElse(ResponseEntity.notFound().build());
  }

  @Operation(summary = "Crear color (ID explícito)")
  @PostMapping
  public ResponseEntity<Color> create(@RequestBody Color color) {
    // Fuerza creación: no permitir ID del cliente
    color.setId(null);
    Color saved = repository.save(color);
    return ResponseEntity.created(URI.create("/api/colors/" + saved.getId())).body(saved);
  }

  @Operation(summary = "Actualizar color")
  @PutMapping("/{id}")
  public ResponseEntity<Color> update(@PathVariable Integer id, @RequestBody Color color) {
    if (!repository.existsById(id)) return ResponseEntity.notFound().build();
    color.setId(id);
    return ResponseEntity.ok(repository.save(color));
  }

  @Operation(summary = "Eliminar color")
  @DeleteMapping("/{id}")
  public ResponseEntity<Void> delete(@PathVariable Integer id) {
    if (!repository.existsById(id)) return ResponseEntity.notFound().build();
    repository.deleteById(id);
    return ResponseEntity.noContent().build();
  }
}
