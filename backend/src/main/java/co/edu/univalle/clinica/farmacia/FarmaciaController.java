package co.edu.univalle.clinica.farmacia;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import co.edu.univalle.clinica.seguridad.UsuarioSesion;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** Recetas, detalles, entregas y medicamentos. Stock y estados los maneja Oracle. */
@RestController
@RequestMapping("/api")
public class FarmaciaController {

    public record RecetaRequest(@NotNull @Positive Long idHistoria) {
    }

    public record DetalleRequest(
            @NotNull @Positive Long idMedicamento,
            @NotNull @Positive Integer cantidad,
            @NotBlank @Size(max = 200) String dosis) {
    }

    public record EntregaRequest(@NotNull @Positive Integer cantidad) {
    }

    private final FarmaciaRepository repo;

    public FarmaciaController(FarmaciaRepository repo) {
        this.repo = repo;
    }

    @PostMapping("/recetas")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> crearReceta(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody RecetaRequest req) {
        return repo.crearReceta(UsuarioSesion.desde(jwt), req);
    }

    @PostMapping("/recetas/{id}/detalle")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> agregarDetalle(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id,
            @Valid @RequestBody DetalleRequest req) {
        return repo.agregarDetalle(UsuarioSesion.desde(jwt), id, req);
    }

    @PostMapping("/recetas/detalle/{id}/entrega")
    public Map<String, Object> registrarEntrega(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id,
            @Valid @RequestBody EntregaRequest req) {
        return repo.registrarEntrega(UsuarioSesion.desde(jwt), id, req);
    }

    @GetMapping("/medicamentos")
    public List<Map<String, Object>> medicamentos(@AuthenticationPrincipal Jwt jwt) {
        return repo.medicamentos(UsuarioSesion.desde(jwt));
    }
}
