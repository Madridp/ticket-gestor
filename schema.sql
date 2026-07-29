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
