import { useState, type FormEvent } from 'react';
import { BarChart3, Search } from 'lucide-react';
import { reportesService } from '../services/reportesService';
import { useConsulta } from '../hooks/useConsulta';
import { Card, PageHeader, StatCard } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoTexto } from '../components/ui/Form';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta } from '../components/ui/Feedback';
import { etiquetaCampo, fechaISO, formatearValor } from '../utils/format';
import type { Fila } from '../types/api';

export default function ReportesPage() {
  const hoy = new Date();
  const [desde, setDesde] = useState(fechaISO(new Date(hoy.getFullYear(), hoy.getMonth(), 1)));
  const [hasta, setHasta] = useState(fechaISO(hoy));
  const [rango, setRango] = useState({ desde, hasta });

  const q = useConsulta((s) => reportesService.resumen(rango.desde, rango.hasta, s), [rango.desde, rango.hasta]);

  function consultar(e: FormEvent) {
    e.preventDefault();
    setRango({ desde, hasta });
  }

  return (
    <>
      <PageHeader titulo="Reportes" descripcion="Indicadores calculados por la base de datos para el periodo elegido." />
      <Card>
        <form className="form-busqueda" onSubmit={consultar}>
          <CampoTexto etiqueta="Desde" type="date" value={desde} onChange={(e) => setDesde(e.target.value)} required />
          <CampoTexto etiqueta="Hasta" type="date" min={desde} value={hasta} onChange={(e) => setHasta(e.target.value)} required />
          <Button type="submit" icono={<Search size={18} />} disabled={!desde || !hasta}>
            Generar
          </Button>
        </form>
      </Card>

      <Card titulo="Resumen" descripcion={`Periodo ${rango.desde} a ${rango.hasta}`} icono={<BarChart3 size={20} />}>
        <EstadoConsulta {...q} vacio={(d) => Object.keys(d).length === 0} textoVacio="No hay datos para el periodo." alReintentar={q.recargar}>
          {(d) => {
            // Valores simples como indicadores; listas como tablas. Sin cálculos en el cliente.
            const simples = Object.entries(d).filter(([, v]) => !Array.isArray(v));
            const listas = Object.entries(d).filter(([, v]) => Array.isArray(v)) as [string, Fila[]][];
            return (
              <>
                {simples.length > 0 && (
                  <div className="grid-stats">
                    {simples.map(([k, v]) => (
                      <StatCard key={k} etiqueta={etiquetaCampo(k)} valor={formatearValor(v)} />
                    ))}
                  </div>
                )}
                {listas.map(([k, filas]) => (
                  <div key={k} className="seccion">
                    <h3 className="seccion__titulo">{etiquetaCampo(k)}</h3>
                    <DataTable filas={filas} />
                  </div>
                ))}
              </>
            );
          }}
        </EstadoConsulta>
      </Card>
    </>
  );
}
