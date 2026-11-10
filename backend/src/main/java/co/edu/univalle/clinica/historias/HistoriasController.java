package co.edu.univalle.clinica.historias;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
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

/** Historias clínicas. Oracle decide qué historias ve cada rol y si la cita puede atenderse. */
@RestController
@RequestMapping("/api/historias")
public class HistoriasController {

    public record HistoriaRequest(
            @NotNull @Positive Long idCita,
            @NotBlank @Size(max = 1000) String diagnostico,
            @Size(max = 4000) String notasMedicas) {
    }

    private final HistoriasRepository repo;

    public HistoriasController(HistoriasRepository repo) {
        this.repo = repo;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> registrar(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody HistoriaRequest req) {
        return repo.registrar(UsuarioSesion.desde(jwt), req);
    }

    @GetMapping
    public List<Map<String, Object>> listar(@AuthenticationPrincipal Jwt jwt) {
        return repo.listar(UsuarioSesion.desde(jwt));
    }
}
