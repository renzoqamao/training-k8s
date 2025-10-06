package pe.com.backend.demo.entities;

import jakarta.persistence.*;
import io.swagger.v3.oas.annotations.media.Schema;
@Entity
@Table(name = "color")
public class Color {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Schema(accessMode = Schema.AccessMode.READ_ONLY)
  @Column(name = "id", nullable = false)
  private Integer id;

  @Column(name = "name", nullable = false, length = 50)
  private String name;

  @Column(name = "red", nullable = false)
  private Integer red;

  @Column(name = "green", nullable = false)
  private Integer green;

  @Column(name = "blue", nullable = false)
  private Integer blue;

  public Color() {}

  public Color(Integer id, String name, Integer red, Integer green, Integer blue) {
    this.id = id; this.name = name; this.red = red; this.green = green; this.blue = blue;
  }

  public Integer getId() { return id; }
  public void setId(Integer id) { this.id = id; }
  public String getName() { return name; }
  public void setName(String name) { this.name = name; }
  public Integer getRed() { return red; }
  public void setRed(Integer red) { this.red = red; }
  public Integer getGreen() { return green; }
  public void setGreen(Integer green) { this.green = green; }
  public Integer getBlue() { return blue; }
  public void setBlue(Integer blue) { this.blue = blue; }
}
