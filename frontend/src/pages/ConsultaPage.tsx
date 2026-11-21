import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { CalendarDays, CheckCircle2, ClipboardCheck, Stethoscope, UserRound } from 'lucide-react';
import { citasService } from '../services/citasService';
import { historiaService } from '../services/historiaService';
import { useConsulta } from '../hooks/useConsulta';
import { useEnvio } from '../hooks/useEnvio';
import { useToast } from '../components/ui/Toast';
import { Badge, Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoArea, CampoTexto } from '../components/ui/Form';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta } from '../components/ui/Feedback';
import { fechaISO, formatearFecha, leerId } from '../utils/format';
import type { CitaMedico } from '../types/citas';

function hora(valor: unknown): string {
  const d = new Date(String(valor));
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' });
}

/**
 * Registro de la atención de una cita (historia clínica).
 * El médico ve SUS citas pendientes del día y elige una; ya no digita el número de cita.
 */
export default function ConsultaPage() {
  const toast = useToast();
  const [fecha, setFecha] = useState(fechaISO(new Date()));
  const [seleccionada, setSeleccionada] = useState<CitaMedico | null>(null);
  const [diagnostico, setDiagnostico] = useState('');
  const [notas, setNotas] = useState('');
  const [registrada, setRegistrada] = useState<number | null>(null);

  const q = useConsulta((s) => citasService.citasDelMedico(fecha, s), [fecha]);
  const envio = useEnvio(historiaService.registrar);

  function cambiarFecha(nueva: string) {
    setFecha(nueva);
    setSeleccionada(null);
  }

  async function enviar(e: FormEvent) {
    e.preventDefault();
    if (!seleccionada || !diagnostico.trim()) return;
    const r = await envio.ejecutar({
      idCita: seleccionada.idCita,
      diagnostico: diagnostico.trim(),
      notasMedicas: notas.trim() || undefined,
    });
    if (r.ok) {
      const id = leerId(r.datos, 'idHistoria', 'id');
      setRegistrada(id);
      toast.mostrar({ tipo: 'exito', titulo: 'Consulta registrada', mensaje: id ? `Historia clínica Nº ${id}` : undefined });
      setSeleccionada(null);
      setDiagnostico('');
      setNotas('');
      q.recargar(); // la cita atendida sale de la lista
    }
  }

  return (
    <>
      <PageHeader titulo="Registrar consulta" descripcion="Elija una de sus citas del día y registre el diagnóstico." />
      {registrada != null && (
        <div className="aviso aviso--exito" role="status">
          <CheckCircle2 size={20} aria-hidden />
          <div>
            <strong>Historia clínica Nº {registrada} registrada.</strong>
            <p>
              Si necesita prescribir medicamentos, <Link to={`/recetas?idHistoria=${registrada}`}>cree la receta</Link>.
            </p>
          </div>
        </div>
      )}

      <Card titulo="Mis citas" descripcion="Citas pendientes de atender en la fecha elegida." icono={<CalendarDays size={20} />}>
        <div className="form-busqueda">
          <CampoTexto etiqueta="Fecha" type="date" value={fecha} onChange={(e) => cambiarFecha(e.target.value)} required />
        </div>
        <EstadoConsulta {...q} textoVacio="No tiene citas pendientes para esta fecha." alReintentar={q.recargar}>
          {(citas) => (
            <DataTable<CitaMedico>
              filas={citas}
              claveFila={(c) => c.idCita}
              columnas={[
                { clave: 'hora', titulo: 'Hora', render: (c) => `${hora(c.fechaHoraInicio)} – ${hora(c.fechaHoraFin)}` },
                { clave: 'paciente', titulo: 'Paciente' },
                { clave: 'documento', titulo: 'Documento' },
                {
                  clave: 'estado',
                  titulo: 'Estado',
                  render: (c) =>
                    c.tieneHistoria === 'S' ? <Badge tono="exito">Atendida</Badge> : <Badge tono="info">Pendiente</Badge>,
                },
              ]}
              acciones={(c) =>
                c.tieneHistoria === 'S' ? (
                  <span className="campo__ayuda">Ya registrada</span>
                ) : (
                  <Button
                    variante={seleccionada?.idCita === c.idCita ? 'primario' : 'secundario'}
                    icono={<ClipboardCheck size={16} />}
                    onClick={() => setSeleccionada(c)}
                  >
                    {seleccionada?.idCita === c.idCita ? 'Seleccionada' : 'Atender'}
                  </Button>
                )
              }
            />
          )}
        </EstadoConsulta>
      </Card>

      {seleccionada && (
        <Card
          titulo="Datos de la atención"
          descripcion={`${seleccionada.paciente} · ${formatearFecha(seleccionada.fechaHoraInicio)}`}
          icono={<Stethoscope size={20} />}
        >
          <form className="form" onSubmit={enviar}>
            <p className="campo__ayuda">
              <UserRound size={14} aria-hidden /> Paciente: <strong>{seleccionada.paciente}</strong> · Doc.{' '}
              {seleccionada.documento} · Cita Nº {seleccionada.idCita}
            </p>
            <CampoArea
              etiqueta="Diagnóstico"
              maxLength={1000}
              rows={3}
              value={diagnostico}
              onChange={(e) => setDiagnostico(e.target.value)}
              required
            />
            <CampoArea
              etiqueta="Notas médicas"
              maxLength={4000}
              rows={6}
              value={notas}
              onChange={(e) => setNotas(e.target.value)}
              ayuda={`${notas.length}/4000 caracteres`}
            />
            <div className="form__acciones">
              <Button variante="secundario" type="button" onClick={() => setSeleccionada(null)}>
                Cambiar de cita
              </Button>
              <Button type="submit" cargando={envio.enviando} disabled={!diagnostico.trim()}>
                Registrar consulta
              </Button>
            </div>
          </form>
        </Card>
      )}
    </>
  );
}