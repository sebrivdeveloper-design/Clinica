package co.edu.univalle.clinica.auth;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import co.edu.univalle.clinica.seguridad.JwtService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public record LoginRequest(@NotBlank String username, @NotBlank String password) {
    }

    public record LoginResponse(String token, String rol, Long idEntidad) {
    }

    private final AuthRepository repo;
    private final JwtService jwt;

    public AuthController(AuthRepository repo, JwtService jwt) {
        this.repo = repo;
        this.jwt = jwt;
    }

    /** Oracle valida las credenciales (PKG_SEGURIDAD.LOGIN). Java solo emite el JWT. */
    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest req) {
        AuthRepository.ResultadoLogin r = repo.login(req.username(), req.password());
        String token = jwt.emitir(r.idUsuario(), req.username(), r.rol(), r.idEntidad());
        return new LoginResponse(token, r.rol(), r.idEntidad());
    }
}
