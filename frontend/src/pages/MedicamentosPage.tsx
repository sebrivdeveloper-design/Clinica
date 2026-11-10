import { useMemo, useState } from 'react';
import { Pill, RefreshCw, Search } from 'lucide-react';
import { farmaciaService } from '../services/farmaciaService';
import { useConsulta } from '../hooks/useConsulta';
import { Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta } from '../components/ui/Feedback';
import type { Medicamento } from '../types/farmacia';

export default function MedicamentosPage() {
  const q = useConsulta((s) => farmaciaService.medicamentos(s), []);
  const [filtro, setFiltro] = useState('');

  const filtrados = useMemo(() => {
    const t = filtro.trim().toLowerCase();
    if (!q.datos || !t) return q.datos;
    return q.datos.filter((m) => `${m.nombre} ${m.descripcion ?? ''} ${m.presentacion ?? ''}`.toLowerCase().includes(t));
  }, [q.datos, filtro]);

  return (
    <>
      <PageHeader
        titulo="Medicamentos"
        descripcion="Catálogo y existencias de la farmacia."
        acciones={
          <Button variante="secundario" icono={<RefreshCw size={16} />} onClick={q.recargar} disabled={q.cargando}>
            Actualizar
          </Button>
        }
      />
      <Card
        titulo="Inventario"
        icono={<Pill size={20} />}
        acciones={
          q.datos && q.datos.length > 0 ? (
            <div className="input-icono input-icono--compacto">
              <Search size={16} aria-hidden />
              <input className="input" placeholder="Buscar medicamento…" aria-label="Buscar medicamento" value={filtro} onChange={(e) => setFiltro(e.target.value)} />
            </div>
          ) : undefined
        }
      >
        <EstadoConsulta {...q} datos={filtrados} textoVacio="No hay medicamentos que coincidan." alReintentar={q.recargar}>
          {(filas) => (
            <DataTable<Medicamento>
              filas={filas}
              claveFila={(m) => m.idMedicamento}
              columnas={[
                { clave: 'idMedicamento', titulo: 'ID' },
                { clave: 'nombre', titulo: 'Nombre' },
                { clave: 'presentacion', titulo: 'Presentación' },
                { clave: 'descripcion', titulo: 'Descripción' },
                { clave: 'cantidadDisponible', titulo: 'Disponible', alinear: 'der' },
                { clave: 'cantidadMinima', titulo: 'Mínimo', alinear: 'der' },
              ]}
            />
          )}
        </EstadoConsulta>
      </Card>
    </>
  );
}
