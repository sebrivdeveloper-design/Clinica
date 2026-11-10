package co.edu.univalle.clinica.reportes;

import java.time.LocalDate;
import java.util.Map;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/** Reportes. Los cálculos los realiza Oracle; Java solo devuelve el resultado. */
@RestController
@RequestMapping("/api/reportes")
public class ReportesController {

    private final ReportesRepository repo;

    public ReportesController(ReportesRepository repo) {
        this.repo = repo;
    }

    @GetMapping("/resumen")
    public Map<String, Object> resumen(@AuthenticationPrincipal Jwt jwt,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        return repo.resumen(UsuarioSesion.desde(jwt), desde, hasta);
    }
}
