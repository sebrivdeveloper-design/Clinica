package co.edu.univalle.clinica.oracle;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Convierte un SYS_REFCURSOR devuelto por un procedimiento en una lista de filas JSON.
 * Las columnas pasan a camelCase: FECHA_HORA_INICIO -> fechaHoraInicio.
 * No transforma ni calcula valores: solo los traslada tal como los entrega Oracle.
 *
 * Uso previsto cuando el equipo implemente los procedimientos de consulta:
 *   cs.registerOutParameter(n, oracle.jdbc.OracleTypes.CURSOR);
 *   cs.execute();
 *   try (ResultSet rs = (ResultSet) cs.getObject(n)) { return CursorMapper.aLista(rs); }
 */
public final class CursorMapper {

    private CursorMapper() {
    }

    public static List<Map<String, Object>> aLista(ResultSet rs) throws SQLException {
        ResultSetMetaData md = rs.getMetaData();
        int n = md.getColumnCount();
        String[] nombres = new String[n];
        for (int i = 0; i < n; i++) {
            nombres[i] = camelCase(md.getColumnLabel(i + 1));
        }
        List<Map<String, Object>> filas = new ArrayList<>();
        while (rs.next()) {
            Map<String, Object> fila = new LinkedHashMap<>();
            for (int i = 0; i < n; i++) {
                Object v = rs.getObject(i + 1);
                if (v instanceof Timestamp t) {
                    v = t.toLocalDateTime();
                } else if (v instanceof java.sql.Date d) {
                    v = d.toLocalDate();
                }
                fila.put(nombres[i], v);
            }
            filas.add(fila);
        }
        return filas;
    }

    static String camelCase(String columna) {
        StringBuilder sb = new StringBuilder();
        boolean mayus = false;
        for (char c : columna.toLowerCase().toCharArray()) {
            if (c == '_') {
                mayus = true;
            } else {
                sb.append(mayus ? Character.toUpperCase(c) : c);
                mayus = false;
            }
        }
        return sb.toString();
    }
}
