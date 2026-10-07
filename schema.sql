-- ============================================================
-- Base de datos del Gestor de Tickets - IGSS Consultorio Chiquimula
-- Ejecuta este script en Supabase: SQL Editor -> New query -> pega -> Run
-- ============================================================

create table if not exists tickets (
  id          bigint generated always as identity primary key,
  categoria   text        not null,
  descripcion text        not null,
  prioridad   text        not null default 'Media',
  estado      text        not null default 'Abierto',
  tecnico     text,
  origen      text        not null default 'Manual',   -- 'Manual' o 'Chatbot'
  created_at  timestamptz not null default now()
);

-- Seguridad a nivel de fila (RLS)
alter table tickets enable row level security;

-- Política PERMISIVA para la demostración del trabajo de graduación:
-- permite leer y escribir con la llave pública (anon).
-- Para producción, restringe estas políticas.
drop policy if exists "acceso_demo" on tickets;
create policy "acceso_demo"
  on tickets for all
  to anon
  using (true)
  with check (true);

-- ============================================================
-- Usuarios del sistema (personal de soporte que atiende los tickets).
-- Distingue el ROL: Administrador (gestiona todo) y Técnico (atiende
-- y da seguimiento a los tickets asignados). El campo tickets.tecnico
-- guarda el nombre del técnico asignado, tomado de esta tabla.
-- ============================================================
create table if not exists usuarios (
  id          bigint generated always as identity primary key,
  nombre      text        not null,
  correo      text        not null,
  rol         text        not null default 'Técnico',   -- 'Administrador' o 'Técnico'
  activo      boolean     not null default true,
  created_at  timestamptz not null default now()
);

alter table usuarios enable row level security;

drop policy if exists "acceso_demo_usuarios" on usuarios;
create policy "acceso_demo_usuarios"
  on usuarios for all
  to anon
  using (true)
  with check (true);

-- Semilla inicial (solo se inserta si la tabla está vacía)
insert into usuarios (nombre, correo, rol)
select v.nombre, v.correo, v.rol
from (values
  ('Pedro García',       'admin@igss',    'Administrador'),
  ('Soporte técnico 1',  'tecnico1@igss', 'Técnico'),
  ('Soporte técnico 2',  'tecnico2@igss', 'Técnico')
) as v(nombre, correo, rol)
where not exists (select 1 from usuarios);
