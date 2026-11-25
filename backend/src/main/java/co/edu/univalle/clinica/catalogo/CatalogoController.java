package co.edu.univalle.clinica.catalogo;

import java.util.List;
import java.util.Map;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/** Listados de apoyo para elegir médico o paciente sin digitar identificadores. Los permisos los valida Oracle. */
@RestController
@RequestMapping("/api")
public class CatalogoController {

    private final CatalogoRepository repo;

    public CatalogoController(CatalogoRepository repo) {
        this.repo = repo;
    }

    @GetMapping("/medicos")
    public List<Map<String, Object>> medicos(@AuthenticationPrincipal Jwt jwt) {
        return repo.medicos(UsuarioSesion.desde(jwt));
    }

    @GetMapping("/pacientes")
    public List<Map<String, Object>> pacientes(@AuthenticationPrincipal Jwt jwt) {
        return repo.pacientes(UsuarioSesion.desde(jwt));
    }
}
