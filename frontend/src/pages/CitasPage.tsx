import { useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { CalendarPlus, CalendarX, CalendarX2 } from 'lucide-react';
import { useSesion } from '../auth/AuthContext';
import { citasService } from '../services/citasService';
import { useEnvio } from '../hooks/useEnvio';
import { useToast } from '../components/ui/Toast';
import { Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoArea, CampoTexto, FilaFormulario, enteroPositivo } from '../components/ui/Form';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';
import { Tabs, type Pestana } from '../components/ui/Tabs';
import { leerId } from '../utils/format';

export default function CitasPage() {
  const sesion = useSesion();
  const esRecepcion = sesion.rol === 'RECEPCIONISTA';
  const pestanas: Pestana[] = [
    { id: 'reservar', etiqueta: 'Reservar', icono: <CalendarPlus size={16} /> },
    ...(esRecepcion
      ? [
          { id: 'cancelar', etiqueta: 'Cancelar', icono: <CalendarX size={16} /> },
          { id: 'masiva', etiqueta: 'Cancelación masiva', icono: <CalendarX2 size={16} /> },
        ]
      : []),
  ];
  const [activa, setActiva] = useState('reservar');

  return (
    <>
      <PageHeader titulo="Citas" descripcion="La disponibilidad y las reglas de cada operación las valida la base de datos." />
      {pestanas.length > 1 && <Tabs pestanas={pestanas} activa={activa} alCambiar={setActiva} />}
      {activa === 'reservar' && <ReservarCita />}
      {activa === 'cancelar' && esRecepcion && <CancelarCita />}
      {activa === 'masiva' && esRecepcion && <CancelacionMasiva />}
    </>
  );
}

function ReservarCita() {
  const sesion = useSesion();
  const toast = useToast();
  const [params] = useSearchParams();
  const esPaciente = sesion.rol === 'PACIENTE';

  const [idPaciente, setIdPaciente] = useState(esPaciente && sesion.idEntidad != null ? String(sesion.idEntidad) : '');
  const [idAgenda, setIdAgenda] = useState(params.get('idAgenda') ?? '');
  const [observacion, setObservacion] = useState('');
  const envio = useEnvio(citasService.reservar);

  const paciente = enteroPositivo(idPaciente);
  const agenda = enteroPositivo(idAgenda);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    if (paciente == null || agenda == null) return;
    const r = await envio.ejecutar({ idPaciente: paciente, idAgenda: agenda, observacion: observacion.trim() || undefined });
    if (r.ok) {
      const id = leerId(r.datos, 'idCita', 'id');
      toast.mostrar({ tipo: 'exito', titulo: 'Cita reservada', mensaje: id ? `Número de cita: ${id}` : undefined });
      setIdAgenda('');
      setObservacion('');
    }
  }

  return (
    <Card titulo="Reservar cita" descripcion="Use un bloque libre de la agenda del médico." icono={<CalendarPlus size={20} />}>
      <form className="form" onSubmit={enviar}>
        <FilaFormulario>
          <CampoTexto
            etiqueta="ID del paciente"
            type="number"
            min={1}
            value={idPaciente}
            onChange={(e) => setIdPaciente(e.target.value)}
            readOnly={esPaciente}
            ayuda={esPaciente ? 'Corresponde a su registro de paciente.' : undefined}
            required
          />
          <CampoTexto
            etiqueta="ID del bloque de agenda"
            type="number"
            min={1}
            value={idAgenda}
            onChange={(e) => setIdAgenda(e.target.value)}
            ayuda="Puede elegirlo desde Agenda médica."
            required
          />
        </FilaFormulario>
        <CampoArea
          etiqueta="Observación"
          maxLength={500}
          rows={3}
          value={observacion}
          onChange={(e) => setObservacion(e.target.value)}
        />
        <div className="form__acciones">
          <Button type="submit" cargando={envio.enviando} disabled={paciente == null || agenda == null}>
            Reservar cita
          </Button>
        </div>
      </form>
    </Card>
  );
}

function CancelarCita() {
  const toast = useToast();
  const [idCita, setIdCita] = useState('');
  const [observacion, setObservacion] = useState('');
  const [confirmar, setConfirmar] = useState(false);
  const envio = useEnvio(citasService.cancelar);
  const cita = enteroPositivo(idCita);

  async function ejecutar() {
    if (cita == null) return;
    const r = await envio.ejecutar(cita, { observacion: observacion.trim() || undefined });
    setConfirmar(false);
    if (r.ok) {
      toast.mostrar({ tipo: 'exito', titulo: 'Cita cancelada', mensaje: `La cita ${cita} fue cancelada.` });
      setIdCita('');
      setObservacion('');
    }
  }

  return (
    <Card titulo="Cancelar cita" icono={<CalendarX size={20} />}>
      <form
        className="form"
        onSubmit={(e) => {
          e.preventDefault();
          if (cita != null) setConfirmar(true);
        }}
      >
        <CampoTexto etiqueta="Número de cita" type="number" min={1} value={idCita} onChange={(e) => setIdCita(e.target.value)} required />
        <CampoArea
          etiqueta="Motivo / observación"
          maxLength={500}
          rows={3}
          value={observacion}
          onChange={(e) => setObservacion(e.target.value)}
        />
        <div className="form__acciones">
          <Button type="submit" variante="peligro" disabled={cita == null}>
            Cancelar cita
          </Button>
        </div>
      </form>
      <ConfirmDialog
        abierto={confirmar}
        titulo={`¿Cancelar la cita ${cita ?? ''}?`}
        textoConfirmar="Sí, cancelar"
        peligro
        cargando={envio.enviando}
        alConfirmar={ejecutar}
        alCancelar={() => setConfirmar(false)}
      >
        <p>El horario quedará liberado si la base de datos aprueba la cancelación.</p>
      </ConfirmDialog>
    </Card>
  );
}

function CancelacionMasiva() {
  const toast = useToast();
  const [idMedico, setIdMedico] = useState('');
  const [desde, setDesde] = useState('');
  const [hasta, setHasta] = useState('');
  const [observacion, setObservacion] = useState('');
  const [confirmar, setConfirmar] = useState(false);
  const envio = useEnvio(citasService.cancelacionMasiva);
  const medico = enteroPositivo(idMedico);
  const completo = medico != null && desde !== '' && hasta !== '';

  async function ejecutar() {
    if (medico == null || !desde || !hasta) return;
    const r = await envio.ejecutar({ idMedico: medico, desde, hasta, observacion: observacion.trim() || undefined });
    setConfirmar(false);
    if (r.ok) {
      const n = leerId(r.datos, 'citasCanceladas', 'cantidad', 'total');
      toast.mostrar({
        tipo: 'exito',
        titulo: 'Cancelación masiva realizada',
        mensaje: n != null ? `Citas canceladas: ${n}` : undefined,
      });
    }
  }

  return (
    <Card
      titulo="Cancelación masiva"
      descripcion="Cancela las citas de un médico en un rango de fechas."
      icono={<CalendarX2 size={20} />}
    >
      <form
        className="form"
        onSubmit={(e) => {
          e.preventDefault();
          if (completo) setConfirmar(true);
        }}
      >
        <FilaFormulario>
          <CampoTexto etiqueta="ID del médico" type="number" min={1} value={idMedico} onChange={(e) => setIdMedico(e.target.value)} required />
          <CampoTexto etiqueta="Desde" type="date" value={desde} onChange={(e) => setDesde(e.target.value)} required />
          <CampoTexto etiqueta="Hasta" type="date" min={desde || undefined} value={hasta} onChange={(e) => setHasta(e.target.value)} required />
        </FilaFormulario>
        <CampoArea
          etiqueta="Motivo / observación"
          maxLength={500}
          rows={3}
          value={observacion}
          onChange={(e) => setObservacion(e.target.value)}
        />
        <div className="form__acciones">
          <Button type="submit" variante="peligro" disabled={!completo}>
            Cancelar citas del periodo
          </Button>
        </div>
      </form>
      <ConfirmDialog
        abierto={confirmar}
        titulo="¿Confirmar cancelación masiva?"
        textoConfirmar="Sí, cancelar todas"
        peligro
        cargando={envio.enviando}
        alConfirmar={ejecutar}
        alCancelar={() => setConfirmar(false)}
      >
        <p>
          Se cancelarán las citas del médico <strong>{idMedico}</strong> entre <strong>{desde}</strong> y{' '}
          <strong>{hasta}</strong>. Esta acción no se puede deshacer desde la aplicación.
        </p>
      </ConfirmDialog>
    </Card>
  );
}
