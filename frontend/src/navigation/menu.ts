import type { LucideIcon } from 'lucide-react';
import {
  BarChart3,
  CalendarClock,
  CalendarPlus,
  ClipboardPlus,
  FileText,
  LayoutDashboard,
  PackageCheck,
  Pill,
  Stethoscope,
} from 'lucide-react';
import type { Rol } from '../types/auth';

export interface ItemMenu {
  ruta: string;
  etiqueta: string;
  descripcion: string;
  icono: LucideIcon;
  roles: readonly Rol[];
}

const TODOS: readonly Rol[] = ['ADMINISTRADOR', 'MEDICO', 'RECEPCIONISTA', 'FARMACEUTICO', 'PACIENTE'];

/**
 * Menú por rol. Es organización VISUAL: Oracle decide si cada operación está permitida.
 * Para agregar un módulo basta con añadir su entrada aquí y su ruta en App.tsx.
 */
export const MENU: ItemMenu[] = [
  { ruta: '/inicio', etiqueta: 'Panel principal', descripcion: 'Resumen y accesos rápidos', icono: LayoutDashboard, roles: TODOS },
  {
    ruta: '/agenda',
    etiqueta: 'Agenda médica',
    descripcion: 'Horarios disponibles por médico',
    icono: CalendarClock,
    roles: ['ADMINISTRADOR', 'MEDICO', 'RECEPCIONISTA', 'PACIENTE'],
  },
  {
    ruta: '/citas',
    etiqueta: 'Citas',
    descripcion: 'Reservar y cancelar citas',
    icono: CalendarPlus,
    roles: ['RECEPCIONISTA', 'PACIENTE'],
  },
  {
    ruta: '/historias',
    etiqueta: 'Historias clínicas',
    descripcion: 'Consultar historias registradas',
    icono: FileText,
    roles: ['ADMINISTRADOR', 'MEDICO', 'PACIENTE'],
  },
  {
    ruta: '/consultas',
    etiqueta: 'Registrar consulta',
    descripcion: 'Atender una cita y registrar el diagnóstico',
    icono: Stethoscope,
    roles: ['MEDICO'],
  },
  {
    ruta: '/recetas',
    etiqueta: 'Recetas médicas',
    descripcion: 'Emitir recetas y prescribir medicamentos',
    icono: ClipboardPlus,
    roles: ['MEDICO'],
  },
  {
    ruta: '/medicamentos',
    etiqueta: 'Medicamentos',
    descripcion: 'Catálogo e inventario de farmacia',
    icono: Pill,
    roles: ['ADMINISTRADOR', 'MEDICO', 'FARMACEUTICO'],
  },
  {
    ruta: '/entregas',
    etiqueta: 'Entregas',
    descripcion: 'Registrar entrega de medicamentos',
    icono: PackageCheck,
    roles: ['FARMACEUTICO'],
  },
  { ruta: '/reportes', etiqueta: 'Reportes', descripcion: 'Resumen de actividad por periodo', icono: BarChart3, roles: ['ADMINISTRADOR'] },
];

export function menuPara(rol: Rol): ItemMenu[] {
  return MENU.filter((m) => m.roles.includes(rol));
}

export function rolesDe(ruta: string): readonly Rol[] {
  return MENU.find((m) => m.ruta === ruta)?.roles ?? [];
}
