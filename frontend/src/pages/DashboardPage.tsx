import { Link } from 'react-router-dom';
import { ArrowRight, BarChart3, CalendarClock, FileText, Pill } from 'lucide-react';
import { useSesion } from '../auth/AuthContext';
import { menuPara } from '../navigation/menu';
import { ETIQUETA_ROL, type Rol } from '../types/auth';
import { Card, PageHeader, StatCard } from '../components/ui/Card';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta } from '../components/ui/Feedback';
import { useConsulta } from '../hooks/useConsulta';
import { citasService } from '../services/citasService';
import { historiaService } from '../services/historiaService';
import { farmaciaService } from '../services/farmaciaService';
import { reportesService } from '../services/reportesService';
import { etiquetaCampo, fechaISO, formatearValor } from '../utils/format';

function saludo(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

export default function DashboardPage() {
  const sesion = useSesion();
  const accesos = menuPara(sesion.rol).filter((m) => m.ruta !== '/inicio');

  return (
    <>
      <PageHeader
        titulo={`${saludo()}, ${sesion.username}`}
        descripcion={`Panel de ${ETIQUETA_ROL[sesion.rol].toLowerCase()}. Seleccione un módulo para comenzar.`}
      />

      <div className="grid-accesos">
        {accesos.map(({ ruta, etiqueta, descripcion, icono: Icono }) => (
          <Link key={ruta} to={ruta} className="acceso">
            <span className="acceso__icono">
              <Icono size={22} aria-hidden />
            </span>
            <span className="acceso__texto">
              <strong>{etiqueta}</strong>
              <small>{descripcion}</small>
            </span>
            <ArrowRight size={18} className="acceso__flecha" aria-hidden />
          </Link>
        ))}
      </div>

      <ResumenRol rol={sesion.rol} idEntidad={sesion.idEntidad} />
    </>
  );
}

/** Un bloque de información en vivo por rol, consumido desde el endpoint correspondiente. */
function ResumenRol({ rol, idEntidad }: { rol: Rol; idEntidad: number | null }) {
  switch (rol) {
    case 'ADMINISTRADOR':
      return <ResumenMes />;
    case 'MEDICO':
      return idEntidad != null ? <ProximosBloques idMedico={idEntidad} /> : null;
    case 'PACIENTE':
      return <UltimasHistorias />;
    case 'FARMACEUTICO':
      return <InventarioBreve />;
    default:
      return null;
  }
}

function ResumenMes() {
  const hoy = new Date();
  const desde = fechaISO(new Date(hoy.getFullYear(), hoy.getMonth(), 1));
  const hasta = fechaISO(hoy);
  const q = useConsulta((s) => reportesService.resumen(desde, hasta, s), [desde, hasta]);
  return (
    <Card titulo="Resumen del mes" descripcion={`Del ${desde} al ${hasta}`} icono={<BarChart3 size={20} />}>
      <EstadoConsulta {...q} vacio={(d) => Object.keys(d).length === 0} alReintentar={q.recargar}>
        {(d) => (
          <div className="grid-stats">
            {Object.entries(d).map(([k, v]) => (
              <StatCard key={k} etiqueta={etiquetaCampo(k)} valor={formatearValor(v)} />
            ))}
          </div>
        )}
      </EstadoConsulta>
    </Card>
  );
}

function ProximosBloques({ idMedico }: { idMedico: number }) {
  const q = useConsulta((s) => citasService.agendaDisponible(idMedico, s), [idMedico]);
  return (
    <Card titulo="Mis próximos horarios libres" icono={<CalendarClock size={20} />}>
      <EstadoConsulta {...q} textoVacio="No tiene bloques libres registrados." alReintentar={q.recargar}>
        {(d) => (
          <DataTable
            filas={d.slice(0, 5)}
            columnas={[{ clave: 'fechaHoraInicio', titulo: 'Inicio' }, { clave: 'fechaHoraFin', titulo: 'Fin' }]}
          />
        )}
      </EstadoConsulta>
    </Card>
  );
}

function UltimasHistorias() {
  const q = useConsulta((s) => historiaService.listar(s), []);
  return (
    <Card titulo="Mis últimas atenciones" icono={<FileText size={20} />}>
      <EstadoConsulta {...q} textoVacio="Aún no tiene historias clínicas registradas." alReintentar={q.recargar}>
        {(d) => (
          <DataTable
            filas={d.slice(0, 5)}
            columnas={[{ clave: 'fechaAtencion', titulo: 'Fecha' }, { clave: 'diagnostico', titulo: 'Diagnóstico' }]}
          />
        )}
      </EstadoConsulta>
    </Card>
  );
}

function InventarioBreve() {
  const q = useConsulta((s) => farmaciaService.medicamentos(s), []);
  return (
    <Card titulo="Inventario de farmacia" icono={<Pill size={20} />}>
      <EstadoConsulta {...q} textoVacio="No hay medicamentos registrados." alReintentar={q.recargar}>
        {(d) => (
          <DataTable
            filas={d.slice(0, 6)}
            columnas={[
              { clave: 'nombre', titulo: 'Medicamento' },
              { clave: 'cantidadDisponible', titulo: 'Disponible', alinear: 'der' },
            ]}
          />
        )}
      </EstadoConsulta>
    </Card>
  );
}
