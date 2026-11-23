import { useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ClipboardList, ClipboardPlus, Pill, RefreshCw } from 'lucide-react';
import { farmaciaService } from '../services/farmaciaService';
import { useConsulta } from '../hooks/useConsulta';
import { useEnvio } from '../hooks/useEnvio';
import { useToast } from '../components/ui/Toast';
import { Badge, Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Campo, CampoTexto, FilaFormulario, enteroPositivo } from '../components/ui/Form';
import { DataTable } from '../components/ui/DataTable';
import { EstadoConsulta } from '../components/ui/Feedback';
import { leerId } from '../utils/format';
import type { DetalleReceta } from '../types/farmacia';

/** Solo presentacion: el estado real lo deduce Oracle. */
function tonoEstado(estado: string): 'exito' | 'alerta' | 'neutro' {
  if (estado === 'Entregado') return 'exito';
  if (estado === 'Entregado parcialmente') return 'alerta';
  return 'neutro';
}

/** Emisión de receta para una historia clínica y prescripción de medicamentos. */
export default function RecetasPage() {
  const toast = useToast();
  const [params] = useSearchParams();

  // --- Paso 1: crear receta ---
  const [idHistoria, setIdHistoria] = useState(params.get('idHistoria') ?? '');
  const crear = useEnvio(farmaciaService.crearReceta);
  const historia = enteroPositivo(idHistoria);

  // --- Paso 2: agregar medicamentos ---
  const [idReceta, setIdReceta] = useState('');
  const [idMedicamento, setIdMedicamento] = useState('');
  const [cantidad, setCantidad] = useState('');
  const [dosis, setDosis] = useState('');
  const agregar = useEnvio(farmaciaService.agregarDetalle);
  const receta = enteroPositivo(idReceta);
  const medicamento = enteroPositivo(idMedicamento);
  const cant = enteroPositivo(cantidad);

  // Receta cuyo contenido se muestra: la ultima creada o a la que se agrego un medicamento.
  const [recetaActiva, setRecetaActiva] = useState<number | null>(null);
  const detalles = useConsulta(recetaActiva ? (s) => farmaciaService.detalleReceta(recetaActiva, s) : null, [recetaActiva]);

  // Catálogo para elegir medicamento; si aún no está disponible se permite escribir el ID.
  const catalogo = useConsulta((s) => farmaciaService.medicamentos(s), []);

  function mostrarReceta(id: number) {
    if (id === recetaActiva) detalles.recargar();
    else setRecetaActiva(id);
  }

  async function crearReceta(e: FormEvent) {
    e.preventDefault();
    if (historia == null) return;
    const r = await crear.ejecutar({ idHistoria: historia });
    if (r.ok) {
      const id = leerId(r.datos, 'idReceta', 'id');
      toast.mostrar({ tipo: 'exito', titulo: 'Receta creada', mensaje: id ? `Receta Nº ${id}` : undefined });
      if (id) {
        setIdReceta(String(id));
        mostrarReceta(id);
      }
    }
  }

  async function agregarDetalle(e: FormEvent) {
    e.preventDefault();
    if (receta == null || medicamento == null || cant == null || !dosis.trim()) return;
    const r = await agregar.ejecutar(receta, { idMedicamento: medicamento, cantidad: cant, dosis: dosis.trim() });
    if (r.ok) {
      const nombre = catalogo.datos?.find((m) => m.idMedicamento === medicamento)?.nombre ?? `ID ${medicamento}`;
      toast.mostrar({ tipo: 'exito', titulo: 'Medicamento agregado', mensaje: nombre });
      setIdMedicamento('');
      setCantidad('');
      setDosis('');
      mostrarReceta(receta);
    }
  }

  return (
    <>
      <PageHeader titulo="Recetas médicas" descripcion="Cree la receta de una historia clínica y agregue los medicamentos." />

      <div className="grid-2">
        <Card titulo="1. Crear receta" icono={<ClipboardPlus size={20} />}>
          <form className="form" onSubmit={crearReceta}>
            <CampoTexto
              etiqueta="Número de historia clínica"
              type="number"
              min={1}
              value={idHistoria}
              onChange={(e) => setIdHistoria(e.target.value)}
              required
            />
            <div className="form__acciones">
              <Button type="submit" cargando={crear.enviando} disabled={historia == null}>
                Crear receta
              </Button>
            </div>
          </form>
        </Card>

        <Card titulo="2. Agregar medicamento" icono={<Pill size={20} />}>
          <form className="form" onSubmit={agregarDetalle}>
            <CampoTexto
              etiqueta="Número de receta"
              type="number"
              min={1}
              value={idReceta}
              onChange={(e) => setIdReceta(e.target.value)}
              required
            />
            {catalogo.datos && catalogo.datos.length > 0 ? (
              <Campo etiqueta="Medicamento" requerido>
                {(id) => (
                  <select id={id} className="input" value={idMedicamento} onChange={(e) => setIdMedicamento(e.target.value)} required>
                    <option value="">Seleccione…</option>
                    {catalogo.datos!.map((m) => (
                      <option key={m.idMedicamento} value={m.idMedicamento}>
                        {m.nombre}
                        {m.presentacion ? ` · ${m.presentacion}` : ''}
                      </option>
                    ))}
                  </select>
                )}
              </Campo>
            ) : (
              <CampoTexto
                etiqueta="ID del medicamento"
                type="number"
                min={1}
                value={idMedicamento}
                onChange={(e) => setIdMedicamento(e.target.value)}
                ayuda={catalogo.error ? 'No se pudo cargar el catálogo de medicamentos; escriba el ID.' : undefined}
                required
              />
            )}
            <FilaFormulario>
              <CampoTexto etiqueta="Cantidad" type="number" min={1} value={cantidad} onChange={(e) => setCantidad(e.target.value)} required />
              <CampoTexto etiqueta="Dosis" maxLength={200} placeholder="Ej. 1 cada 8 horas" value={dosis} onChange={(e) => setDosis(e.target.value)} required />
            </FilaFormulario>
            <div className="form__acciones">
              <Button
                type="submit"
                cargando={agregar.enviando}
                disabled={receta == null || medicamento == null || cant == null || !dosis.trim()}
              >
                Agregar a la receta
              </Button>
            </div>
          </form>
        </Card>
      </div>

      {recetaActiva != null && (
        <Card
          titulo={`Medicamentos de la receta ${recetaActiva}`}
          descripcion="Tal como están registrados en la base de datos."
          icono={<ClipboardList size={20} />}
          acciones={
            <Button variante="secundario" icono={<RefreshCw size={16} />} onClick={detalles.recargar} disabled={detalles.cargando}>
              Actualizar
            </Button>
          }
        >
          <EstadoConsulta {...detalles} textoVacio="La receta aún no tiene medicamentos. Agréguelos en el paso 2." alReintentar={detalles.recargar}>
            {(filas) => (
              <DataTable<DetalleReceta>
                filas={filas}
                claveFila={(d) => d.idDetalle}
                columnas={[
                  { clave: 'medicamento', titulo: 'Medicamento' },
                  { clave: 'dosis', titulo: 'Dosis' },
                  { clave: 'cantidad', titulo: 'Recetado', alinear: 'der' },
                  { clave: 'cantidadEntregada', titulo: 'Entregado', alinear: 'der' },
                  { clave: 'cantidadPendiente', titulo: 'Pendiente', alinear: 'der' },
                  { clave: 'estado', titulo: 'Estado', render: (d) => <Badge tono={tonoEstado(d.estado)}>{d.estado}</Badge> },
                  { clave: 'farmaceutico', titulo: 'Entregó' },
                  { clave: 'fechaEntrega', titulo: 'Fecha de entrega' },
                ]}
              />
            )}
          </EstadoConsulta>
        </Card>
      )}
    </>
  );
}
