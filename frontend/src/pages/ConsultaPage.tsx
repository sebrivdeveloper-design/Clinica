import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { CheckCircle2, Stethoscope } from 'lucide-react';
import { historiaService } from '../services/historiaService';
import { useEnvio } from '../hooks/useEnvio';
import { useToast } from '../components/ui/Toast';
import { Card, PageHeader } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { CampoArea, CampoTexto, enteroPositivo } from '../components/ui/Form';
import { leerId } from '../utils/format';

/** Registro de la atención de una cita (historia clínica). */
export default function ConsultaPage() {
  const toast = useToast();
  const [idCita, setIdCita] = useState('');
  const [diagnostico, setDiagnostico] = useState('');
  const [notas, setNotas] = useState('');
  const [registrada, setRegistrada] = useState<number | null>(null);
  const envio = useEnvio(historiaService.registrar);
  const cita = enteroPositivo(idCita);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    if (cita == null || !diagnostico.trim()) return;
    const r = await envio.ejecutar({ idCita: cita, diagnostico: diagnostico.trim(), notasMedicas: notas.trim() || undefined });
    if (r.ok) {
      const id = leerId(r.datos, 'idHistoria', 'id');
      setRegistrada(id);
      toast.mostrar({ tipo: 'exito', titulo: 'Consulta registrada', mensaje: id ? `Historia clínica Nº ${id}` : undefined });
      setIdCita('');
      setDiagnostico('');
      setNotas('');
    }
  }

  return (
    <>
      <PageHeader titulo="Registrar consulta" descripcion="Registre el diagnóstico de una cita atendida." />
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
      <Card titulo="Datos de la atención" icono={<Stethoscope size={20} />}>
        <form className="form" onSubmit={enviar}>
          <CampoTexto etiqueta="Número de cita" type="number" min={1} value={idCita} onChange={(e) => setIdCita(e.target.value)} required />
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
            <Button type="submit" cargando={envio.enviando} disabled={cita == null || !diagnostico.trim()}>
              Registrar consulta
            </Button>
          </div>
        </form>
      </Card>
    </>
  );
}
