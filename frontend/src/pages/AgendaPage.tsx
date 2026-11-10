import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { CalendarClock, CalendarPlus, Search } from 'lucide-react';
import { useSesion } from '../auth/AuthContext';
import { citasService } from '../services/citasService';
import { useConsulta } from '../hooks/useConsulta';
import { Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoTexto, enteroPositivo } from '../components/ui/Form';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta, EstadoVacio } from '../components/ui/Feedback';
import type { BloqueAgenda } from '../types/citas';

export default function AgendaPage() {
  const sesion = useSesion();
  const navigate = useNavigate();
  const esMedico = sesion.rol === 'MEDICO';
  const puedeReservar = sesion.rol === 'RECEPCIONISTA' || sesion.rol === 'PACIENTE';

  // El médico consulta su propia agenda; los demás roles eligen el médico.
  const [texto, setTexto] = useState(esMedico && sesion.idEntidad != null ? String(sesion.idEntidad) : '');
  const [idMedico, setIdMedico] = useState<number | null>(esMedico ? sesion.idEntidad : null);

  const q = useConsulta(idMedico != null ? (s) => citasService.agendaDisponible(idMedico, s) : null, [idMedico]);

  function buscar(e: FormEvent) {
    e.preventDefault();
    setIdMedico(enteroPositivo(texto));
  }

  return (
    <>
      <PageHeader
        titulo={esMedico ? 'Mi agenda' : 'Agenda médica'}
        descripcion="Bloques de horario disponibles para reservar citas."
      />

      {!esMedico && (
        <Card>
          <form className="form-busqueda" onSubmit={buscar}>
            <CampoTexto
              etiqueta="ID del médico"
              type="number"
              min={1}
              inputMode="numeric"
              value={texto}
              onChange={(e) => setTexto(e.target.value)}
              required
            />
            <Button type="submit" icono={<Search size={18} />} disabled={enteroPositivo(texto) == null}>
              Consultar
            </Button>
          </form>
        </Card>
      )}

      <Card titulo="Horarios disponibles" icono={<CalendarClock size={20} />}>
        {idMedico == null ? (
          <EstadoVacio titulo="Seleccione un médico" texto="Ingrese el identificador del médico para ver su agenda." />
        ) : (
          <EstadoConsulta {...q} textoVacio="El médico no tiene bloques libres." alReintentar={q.recargar}>
            {(bloques) => (
              <DataTable<BloqueAgenda>
                filas={bloques}
                claveFila={(b) => b.idAgenda}
                columnas={[
                  { clave: 'idAgenda', titulo: 'Bloque' },
                  { clave: 'fechaHoraInicio', titulo: 'Inicio' },
                  { clave: 'fechaHoraFin', titulo: 'Fin' },
                ]}
                acciones={
                  puedeReservar
                    ? (b) => (
                        <Button
                          variante="secundario"
                          icono={<CalendarPlus size={16} />}
                          onClick={() => navigate(`/citas?idAgenda=${b.idAgenda}`)}
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
