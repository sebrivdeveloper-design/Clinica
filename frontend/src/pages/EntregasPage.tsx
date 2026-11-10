import { useState } from 'react';
import { Info, PackageCheck } from 'lucide-react';
import { farmaciaService } from '../services/farmaciaService';
import { useEnvio } from '../hooks/useEnvio';
import { useToast } from '../components/ui/Toast';
import { Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoTexto, FilaFormulario, enteroPositivo } from '../components/ui/Form';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';

/** Registro de entrega (total o parcial) de un medicamento de una receta. */
export default function EntregasPage() {
  const toast = useToast();
  const [idDetalle, setIdDetalle] = useState('');
  const [cantidad, setCantidad] = useState('');
  const [confirmar, setConfirmar] = useState(false);
  const envio = useEnvio(farmaciaService.registrarEntrega);
  const detalle = enteroPositivo(idDetalle);
  const cant = enteroPositivo(cantidad);

  async function ejecutar() {
    if (detalle == null || cant == null) return;
    const r = await envio.ejecutar(detalle, { cantidad: cant });
    setConfirmar(false);
    if (r.ok) {
      toast.mostrar({ tipo: 'exito', titulo: 'Entrega registrada', mensaje: `Detalle ${detalle}: ${cant} unidad(es) entregadas.` });
      setIdDetalle('');
      setCantidad('');
    }
  }

  return (
    <>
      <PageHeader titulo="Entregas de medicamentos" descripcion="El stock y el estado de la receta los actualiza la base de datos." />
      <Card titulo="Registrar entrega" icono={<PackageCheck size={20} />}>
        <form
          className="form"
          onSubmit={(e) => {
            e.preventDefault();
            if (detalle != null && cant != null) setConfirmar(true);
          }}
        >
          <FilaFormulario>
            <CampoTexto
              etiqueta="Número de detalle de receta"
              type="number"
              min={1}
              value={idDetalle}
              onChange={(e) => setIdDetalle(e.target.value)}
              required
            />
            <CampoTexto etiqueta="Cantidad a entregar" type="number" min={1} value={cantidad} onChange={(e) => setCantidad(e.target.value)} required />
          </FilaFormulario>
          <div className="form__acciones">
            <Button type="submit" disabled={detalle == null || cant == null}>
              Registrar entrega
            </Button>
          </div>
        </form>
      </Card>

      <div className="aviso aviso--info">
        <Info size={20} aria-hidden />
        <div>
          <strong>Consulta de recetas</strong>
          <p>
            El contrato actual de la API no incluye un endpoint para listar recetas ni sus detalles; la entrega se registra
            con el número de detalle indicado en la receta.
          </p>
        </div>
      </div>

      <ConfirmDialog
        abierto={confirmar}
        titulo="¿Registrar la entrega?"
        textoConfirmar="Registrar"
        cargando={envio.enviando}
        alConfirmar={ejecutar}
        alCancelar={() => setConfirmar(false)}
      >
        <p>
          Se entregarán <strong>{cantidad}</strong> unidad(es) del detalle <strong>{idDetalle}</strong>. La base de datos
          descontará el inventario.
        </p>
      </ConfirmDialog>
    </>
  );
}
