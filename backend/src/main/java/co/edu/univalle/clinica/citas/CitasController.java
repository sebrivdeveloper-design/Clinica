package co.edu.univalle.clinica.citas;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import co.edu.univalle.clinica.seguridad.UsuarioSesion;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** Agenda y citas. Toda regla (disponibilidad, estados, cancelación) la aplica Oracle. */
@RestController
@RequestMapping("/api")
public class CitasController {

    public record ReservaCitaRequest(
            @NotNull @Positive Long idPaciente,
            @NotNull @Positive Long idAgenda,
            @Size(max = 500) String observacion) {
    }

    public record CancelarCitaRequest(@Size(max = 500) String observacion) {
    }

    public record CancelacionMasivaRequest(
            @NotNull @Positive Long idMedico,
            @NotNull LocalDate desde,
            @NotNull LocalDate hasta,
            @Size(max = 500) String observacion) {
    }

    private final CitasRepository repo;

    public CitasController(CitasRepository repo) {
        this.repo = repo;
    }

    @GetMapping("/agenda/disponible")
    public List<Map<String, Object>> agendaDisponible(@AuthenticationPrincipal Jwt jwt,
            @RequestParam Long idMedico) {
        return repo.agendaDisponible(UsuarioSesion.desde(jwt), idMedico);
    }

    @PostMapping("/citas")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> reservar(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ReservaCitaRequest req) {
        return repo.reservar(UsuarioSesion.desde(jwt), req);
    }

    @PutMapping("/citas/{id}/cancelar")
    public Map<String, Object> cancelar(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id,
            @Valid @RequestBody(required = false) CancelarCitaRequest req) {
        return repo.cancelar(UsuarioSesion.desde(jwt), id, req == null ? null : req.observacion());
    }

    @PostMapping("/citas/cancelacion-masiva")
    public Map<String, Object> cancelacionMasiva(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CancelacionMasivaRequest req) {
        return repo.cancelacionMasiva(UsuarioSesion.desde(jwt), req);
    }
}
