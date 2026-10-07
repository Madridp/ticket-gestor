# Gestor de Tickets con Chatbot — Guía de despliegue

Sistema web de gestión de incidentes para el IGSS Consultorio Chiquimula, con **base de datos real (Supabase/PostgreSQL)** y **chatbot** que también registra tickets. Se despliega en **Vercel**.

Archivos:
- `index.html` — la aplicación completa (interfaz, tickets, chatbot).
- `schema.sql` — crea las tablas de **tickets** y **usuarios** (técnicos y administrador) en la base de datos.
- `README_DESPLIEGUE.md` — esta guía.

> **Si ya tenías la base de datos creada antes:** vuelve a abrir el **SQL Editor** de Supabase y ejecuta de nuevo `schema.sql` completo. Es seguro: no borra tus tickets y solo agrega la tabla `usuarios` con el personal de soporte. Si no lo ejecutas, la app igual funciona con una lista de técnicos por defecto, pero los usuarios que agregues no se guardarán de forma permanente.

**Login de demostración:** usuario `admin@igss` · contraseña `igss2025`

---

## Paso 1 — Crear la base de datos (Supabase, gratis)

1. Entra a **https://supabase.com** → *Start your project* → crea una cuenta (con tu correo o GitHub).
2. *New project* → ponle un nombre (ej. `ticket-gestor`), define una contraseña de base de datos y crea.
3. Cuando cargue, ve a **SQL Editor** (icono `</>`) → *New query*.
4. Abre `schema.sql`, copia **todo** su contenido, pégalo y presiona **Run**. Debe decir *Success*.

## Paso 2 — Copiar tus llaves

1. En Supabase ve a **Project Settings** (engranaje) → **API**.
2. Copia dos valores:
   - **Project URL** (algo como `https://xxxxx.supabase.co`)
   - **anon public** key (una cadena larga)

## Paso 3 — Pegar las llaves en la app

1. Abre `index.html` con un editor de texto (Bloc de notas, VS Code…).
2. Busca este bloque (cerca del inicio del `<script>`):

   ```js
   const SUPABASE_URL = "TU_SUPABASE_URL";
   const SUPABASE_ANON_KEY = "TU_SUPABASE_ANON_KEY";
   ```
3. Reemplaza los textos por tus valores reales del Paso 2 y guarda.

> Nota: la *anon key* es pública por diseño (va en el navegador); no es un secreto. Aun así, no compartas la contraseña de la base de datos ni la *service_role key*.

## Paso 4 — Probar en tu computadora

Haz doble clic en `index.html`. Inicia sesión con `admin@igss` / `igss2025`, crea un ticket y abre el chatbot (botón 💬). Si el ticket aparece en el módulo **Tickets** y sigue ahí al recargar la página, ¡la base de datos funciona!

Si ves un aviso amarillo de "base de datos no configurada", revisa el Paso 3.

## Paso 5 — Subir a Vercel

Es un sitio estático (sin build), así que es directo:

**Opción A — Vercel CLI (rápida)**
1. Instala Node.js (si no lo tienes) y luego en una terminal: `npm i -g vercel`
2. Entra a la carpeta `ticket-gestor` y ejecuta: `vercel`
3. Acepta las preguntas por defecto. Al terminar te da la URL pública.

**Opción B — GitHub + Vercel (recomendada para tenerlo versionado)**
1. Sube la carpeta `ticket-gestor` a un repositorio de GitHub.
2. Entra a **https://vercel.com/new**, importa el repositorio.
3. En *Framework Preset* deja **Other**, sin build command. Clic en **Deploy**.
4. Vercel te entrega la URL (ej. `https://ticket-gestor.vercel.app`).

Ese enlace es el que adjuntas en tu tesis.

---

## Cómo se relaciona con tu tesis
- **Módulos:** Login, Dashboard, Tickets (registrar/clasificar/asignar a un técnico/dar seguimiento), Base de conocimientos, Usuarios (personal de soporte con roles Administrador y Técnico, y carga de trabajo por técnico) y Configuración.
- **Chatbot:** interpreta la intención del usuario, propone una solución de la base de conocimientos y, si el problema persiste, **crea el ticket automáticamente** en la misma base de datos (queda marcado con origen `Chatbot`).
- **Base de datos:** PostgreSQL en Supabase; los tickets se guardan de forma permanente.

## Evidencia para la Dra. Esquivel
Con el sistema en línea puedes capturar: la pantalla de login, el dashboard, el listado de tickets, y el chatbot creando un ticket. Esas capturas sirven para el Anexo 2 y para la figura del chatbot.

---

## Activar la IA del chatbot (opcional pero recomendado)

El chatbot funciona de dos formas:
- **Sin IA:** usa la base de conocimientos por reglas (funciona siempre, incluso local).
- **Con IA (Gemini):** responde de forma natural cualquier pregunta, apoyándose en la base de conocimientos. Si la IA falla, vuelve automáticamente a las reglas.

Para activar la IA:

1. Entra a **https://aistudio.google.com/apikey** con tu cuenta de Google y crea una **API key** (Gemini tiene plan gratuito).
2. En Vercel, abre tu proyecto > **Settings** > **Environment Variables**.
3. Agrega una variable:
   - **Name:** `GEMINI_API_KEY`
   - **Value:** (pega tu API key)
   - Aplícala a *Production* (y *Preview* si quieres).
4. Ve a **Deployments** > menú del último despliegue > **Redeploy** (o haz un nuevo push).

**Importante:** sube al repositorio la carpeta **`api/`** (con `api/chat.js`), no solo el `index.html`. Vercel la convierte automáticamente en la función de servidor que llama a la IA. La API key queda solo en el servidor, nunca en el navegador.

Si no configuras la key, no pasa nada: el chatbot sigue funcionando con la base de conocimientos.
