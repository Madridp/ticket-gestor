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

-- Datos de quién reporta y evidencia inicial
alter table tickets add column if not exists solicitante     text;        -- nombre de quien reporta
alter table tickets add column if not exists area            text;        -- área o unidad del solicitante
alter table tickets add column if not exists fotos           text;        -- fotos del problema al reportar (JSON)
alter table tickets add column if not exists historial       text;        -- seguimiento/trazabilidad del ticket (JSON)

-- Columnas de resolución (cómo quedó resuelto el ticket al cerrarlo)
alter table tickets add column if not exists solucion       text;        -- descripción de la solución
alter table tickets add column if not exists solucion_fotos  text;        -- fotos de evidencia (JSON con imágenes)
alter table tickets add column if not exists cerrado_por      text;        -- técnico que resolvió
alter table tickets add column if not exists cerrado_at       timestamptz; -- fecha/hora de cierre

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

-- Técnicos de soporte adicionales (se agregan aunque la tabla ya tenga datos)
insert into usuarios (nombre, correo, rol)
select v.nombre, v.correo, v.rol
from (values
  ('Soporte técnico 3',  'tecnico3@igss', 'Técnico'),
  ('Soporte técnico 4',  'tecnico4@igss', 'Técnico')
) as v(nombre, correo, rol)
where not exists (select 1 from usuarios u where u.correo = v.correo);

-- ============================================================
-- Registro de la evaluación (prueba piloto): una fila por consulta al chatbot
-- resultado: resuelto_chatbot | ticket | sin_resolver
-- ============================================================
create table if not exists evaluacion_chat (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  consulta    text,
  resultado   text,
  via         text,          -- 'ia' o 'reglas'
  categoria   text,
  ticket_id   bigint,
  segundos    integer        -- tiempo desde la consulta hasta el resultado
);
alter table evaluacion_chat enable row level security;
drop policy if exists "acceso_demo_evaluacion" on evaluacion_chat;
create policy "acceso_demo_evaluacion" on evaluacion_chat
  for all to anon using (true) with check (true);


-- ============================================================
-- Asignación automática de tickets
-- Si un ticket abierto lleva más de 10 minutos sin técnico asignado,
-- se asigna al técnico activo con menos tickets abiertos o en proceso.
-- La revisión se ejecuta cada minuto en la base de datos (pg_cron).
-- ============================================================
create or replace function asignar_tickets_pendientes(minutos integer default 10)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  t   record;
  tec text;
  n   integer := 0;
begin
  for t in
    select id from tickets
    where (tecnico is null or tecnico = '')
      and estado <> 'Cerrado'
      and created_at < now() - make_interval(mins => minutos)
    order by created_at
    for update skip locked
  loop
    -- técnico activo más desocupado (menos tickets sin cerrar); en empate, el de menor id
    select u.nombre into tec
    from usuarios u
    where u.activo and u.rol = 'Técnico'
    order by (select count(*) from tickets k
              where k.tecnico = u.nombre and k.estado <> 'Cerrado') asc, u.id asc
    limit 1;

    exit when tec is null;   -- no hay técnicos activos

    update tickets
       set tecnico   = tec,
           historial = (coalesce(nullif(historial, ''), '[]')::jsonb
                        || jsonb_build_array(jsonb_build_object(
                             't',   to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
                             'e',   'Asignado automáticamente a ' || tec || ' (sin asignar por más de ' || minutos || ' minutos)',
                             'por', 'Sistema')))::text
     where id = t.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Programar la revisión cada minuto (pg_cron)
create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'asignacion-automatica';
select cron.schedule('asignacion-automatica', '* * * * *', 'select asignar_tickets_pendientes(10)');


-- Refresca la caché de la API para que reconozca las columnas nuevas de inmediato
notify pgrst, 'reload schema';
