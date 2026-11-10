import { useMemo, useState } from 'react';
import { FileText, RefreshCw, Search } from 'lucide-react';
import { useSesion } from '../auth/AuthContext';
import { historiaService } from '../services/historiaService';
import { useConsulta } from '../hooks/useConsulta';
import { Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta } from '../components/ui/Feedback';
import type { HistoriaClinica } from '../types/historia';

export default function HistoriasPage() {
  const sesion = useSesion();
  const q = useConsulta((s) => historiaService.listar(s), []);
  const [filtro, setFiltro] = useState('');

  // Filtro de texto solo sobre lo que ya devolvió Oracle (presentación).
  const filtradas = useMemo(() => {
    const t = filtro.trim().toLowerCase();
    if (!q.datos || !t) return q.datos;
    return q.datos.filter((h) => Object.values(h).some((v) => String(v ?? '').toLowerCase().includes(t)));
  }, [q.datos, filtro]);

  return (
    <>
      <PageHeader
        titulo={sesion.rol === 'PACIENTE' ? 'Mi historia clínica' : 'Historias clínicas'}
        descripcion="La base de datos determina qué registros puede ver cada usuario."
        acciones={
          <Button variante="secundario" icono={<RefreshCw size={16} />} onClick={q.recargar} disabled={q.cargando}>
            Actualizar
          </Button>
        }
      />
      <Card
        titulo="Registros"
        icono={<FileText size={20} />}
        acciones={
          q.datos && q.datos.length > 0 ? (
            <div className="input-icono input-icono--compacto">
              <Search size={16} aria-hidden />
              <input
                className="input"
                placeholder="Buscar…"
                aria-label="Buscar en historias"
                value={filtro}
                onChange={(e) => setFiltro(e.target.value)}
              />
            </div>
          ) : undefined
        }
      >
        <EstadoConsulta {...q} datos={filtradas} textoVacio="No hay historias clínicas para mostrar." alReintentar={q.recargar}>
          {(filas) => (
            <DataTable<HistoriaClinica>
              filas={filas}
              claveFila={(h) => h.idHistoria}
              columnas={[
                { clave: 'idHistoria', titulo: 'Historia' },
                { clave: 'idCita', titulo: 'Cita' },
                { clave: 'fechaAtencion', titulo: 'Fecha de atención' },
                { clave: 'diagnostico', titulo: 'Diagnóstico' },
                { clave: 'notasMedicas', titulo: 'Notas', render: (h) => <span className="texto-largo">{h.notasMedicas ?? '—'}</span> },
              ]}
            />
          )}
        </EstadoConsulta>
      </Card>
    </>
  );
}
