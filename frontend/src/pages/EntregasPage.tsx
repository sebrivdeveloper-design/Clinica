import { useCallback, useState } from 'react';
import { PackageCheck, RefreshCw } from 'lucide-react';
import { farmaciaService } from '../services/farmaciaService';
import { useConsulta } from '../hooks/useConsulta';
import { useEnvio } from '../hooks/useEnvio';
import { useToast } from '../components/ui/Toast';
import { Badge, Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoTexto, enteroPositivo } from '../components/ui/Form';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta } from '../components/ui/Feedback';
import type { DetallePendiente } from '../types/farmacia';

/** Solo presentacion: el estado real lo deduce Oracle. */
function tonoEstado(estado: string): 'alerta' | 'neutro' {
  return estado === 'Entregado parcialmente' ? 'alerta' : 'neutro';
}

/** Entrega (total o parcial) de los medicamentos recetados que aun estan pendientes. */
export default function EntregasPage() {
  const toast = useToast();
  const q = useConsulta((s) => farmaciaService.detallesPendientes(s), []);
  const envio = useEnvio(farmaciaService.registrarEntrega);

  const [seleccionado, setSeleccionado] = useState<DetallePendiente | null>(null);
  const [cantidad, setCantidad] = useState('');
  const cant = enteroPositivo(cantidad);

  function abrir(d: DetallePendiente) {
    setSeleccionado(d);
    setCantidad(String(d.cantidadPendiente));
  }

  // Estable entre renderizados: ConfirmDialog vuelve a enfocar "Cancelar" cada vez que cambia alCancelar,
  // lo que sacaria el cursor del campo de cantidad en cada tecla.
  const cerrar = useCallback(() => {
    setSeleccionado(null);
    setCantidad('');
  }, []);

  async function ejecutar() {
    if (!seleccionado || cant == null) return;
    const r = await envio.ejecutar(seleccionado.idDetalle, { cantidad: cant });
    if (r.ok) {
      const { cantidadPendiente, estadoDetalle, estadoReceta } = r.datos;
      toast.mostrar({
        tipo: 'exito',
        titulo: 'Entrega registrada',
        mensaje: `${seleccionado.medicamento}: ${cant} unidad(es). Pendiente: ${cantidadPendiente}. Medicamento: ${estadoDetalle}. Receta: ${estadoReceta}.`,
      });
    }
    // En ambos casos se cierra y se recarga: si hubo error, el stock o lo pendiente pudo cambiar.
    cerrar();
    q.recargar();
  }

  return (
    <>
      <PageHeader
        titulo="Entregas de medicamentos"
        descripcion="Medicamentos recetados con cantidad pendiente. El stock y el estado de la receta los actualiza la base de datos."
        acciones={
          <Button variante="secundario" icono={<RefreshCw size={16} />} onClick={q.recargar} disabled={q.cargando}>
            Actualizar
          </Button>
        }
      />

      <Card titulo="Pendientes por entregar" icono={<PackageCheck size={20} />}>
        <EstadoConsulta {...q} textoVacio="No hay medicamentos pendientes de entrega." alReintentar={q.recargar}>
          {(filas) => (
            <DataTable<DetallePendiente>
              filas={filas}
              claveFila={(d) => d.idDetalle}
              columnas={[
                { clave: 'idReceta', titulo: 'Receta' },
                { clave: 'fechaEmision', titulo: 'Emitida' },
                { clave: 'paciente', titulo: 'Paciente' },
                { clave: 'medicamento', titulo: 'Medicamento' },
                { clave: 'dosis', titulo: 'Dosis' },
                { clave: 'cantidad', titulo: 'Recetado', alinear: 'der' },
                { clave: 'cantidadPendiente', titulo: 'Pendiente', alinear: 'der' },
                { clave: 'stockDisponible', titulo: 'Stock', alinear: 'der' },
                { clave: 'estado', titulo: 'Estado', render: (d) => <Badge tono={tonoEstado(d.estado)}>{d.estado}</Badge> },
              ]}
              acciones={(d) => (
                <Button variante="secundario" onClick={() => abrir(d)}>
                  Entregar
                </Button>
              )}
            />
          )}
        </EstadoConsulta>
      </Card>

      <ConfirmDialog
        abierto={seleccionado != null}
        titulo="¿Registrar la entrega?"
        textoConfirmar="Registrar"
        cargando={envio.enviando}
        alConfirmar={ejecutar}
        alCancelar={cerrar}
      >
        {seleccionado && (
          <>
            <p>
              <strong>{seleccionado.medicamento}</strong> para {seleccionado.paciente}. Pendiente:{' '}
              <strong>{seleccionado.cantidadPendiente}</strong>. Stock disponible: <strong>{seleccionado.stockDisponible ?? 0}</strong>.
            </p>
            <CampoTexto
              etiqueta="Cantidad a entregar"
              type="number"
              min={1}
              value={cantidad}
              onChange={(e) => setCantidad(e.target.value)}
              ayuda={
                cant == null
                  ? 'Ingrese un número entero mayor que 0.'
                  : 'Si supera el stock disponible, la base de datos rechaza la entrega.'
              }
              required
            />
          </>
        )}
      </ConfirmDialog>
    </>
  );
}
