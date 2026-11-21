import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CalendarClock, CalendarPlus } from 'lucide-react';
import { useSesion } from '../auth/AuthContext';
import { citasService } from '../services/citasService';
import { useConsulta } from '../hooks/useConsulta';
import { Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoSeleccion } from '../components/ui/Form';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta, EstadoVacio } from '../components/ui/Feedback';
import type { BloqueAgenda } from '../types/citas';

export default function AgendaPage() {
  const sesion = useSesion();
  const navigate = useNavigate();
  const esMedico = sesion.rol === 'MEDICO';
  // Todos los roles con acceso a la agenda pueden reservar desde un bloque libre.
  const puedeReservar = ['ADMINISTRADOR', 'RECEPCIONISTA', 'MEDICO', 'PACIENTE'].includes(sesion.rol);

  // El médico consulta su propia agenda; los demás roles eligen el médico por nombre.
  const [idMedico, setIdMedico] = useState<number | null>(esMedico ? sesion.idEntidad : null);

  const medicos = useConsulta((s) => citasService.medicos(s), []);
  const q = useConsulta(idMedico != null ? (s) => citasService.agendaDisponible(idMedico, s) : null, [idMedico]);

  return (
    <>
      <PageHeader
        titulo={esMedico ? 'Mi agenda' : 'Agenda médica'}
        descripcion="Bloques de horario disponibles para reservar citas."
      />

      {!esMedico && (
        <Card>
          <EstadoConsulta {...medicos} textoVacio="No hay médicos registrados." alReintentar={medicos.recargar}>
            {(lista) => (
              <div className="form-busqueda">
                <CampoSeleccion
                  etiqueta="Médico"
                  value={idMedico ?? ''}
                  onChange={(e) => setIdMedico(e.target.value ? Number(e.target.value) : null)}
                >
                  <option value="">Seleccione un médico…</option>
                  {lista.map((m) => (
                    <option key={m.idMedico} value={m.idMedico}>
                      {m.nombre} — {m.especialidad}
                    </option>
                  ))}
                </CampoSeleccion>
              </div>
            )}
          </EstadoConsulta>
        </Card>
      )}

      <Card titulo="Horarios disponibles" icono={<CalendarClock size={20} />}>
        {idMedico == null ? (
          <EstadoVacio titulo="Seleccione un médico" texto="Elija un médico de la lista para ver su agenda." />
        ) : (
          <EstadoConsulta {...q} textoVacio="El médico no tiene bloques libres." alReintentar={q.recargar}>
            {(bloques) => (
              <DataTable<BloqueAgenda>
                filas={bloques}
                claveFila={(b) => b.idAgenda}
                columnas={[
                  { clave: 'fechaHoraInicio', titulo: 'Inicio' },
                  { clave: 'fechaHoraFin', titulo: 'Fin' },
                ]}
                acciones={
                  puedeReservar
                    ? (b) => (
                        <Button
                          variante="secundario"
                          icono={<CalendarPlus size={16} />}
                          onClick={() => navigate(`/citas?idAgenda=${b.idAgenda}&idMedico=${idMedico}`)}
                        >
                          Reservar
                        </Button>
                      )
                    : undefined
                }
              />
            )}
          </EstadoConsulta>
        )}
      </Card>
    </>
  );
}