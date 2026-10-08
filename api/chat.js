// Función serverless de Vercel: asistente de soporte con IA (Google Gemini)
// La API key se toma de la variable de entorno GEMINI_API_KEY (configurar en Vercel).
// Si no hay key o falla, devuelve reply:null y el frontend usa el motor de reglas.

export default async function handler(req, res) {
  res.setHeader('Content-Type', 'application/json');
  if (req.method !== 'POST') { res.status(405).json({ error: 'Método no permitido' }); return; }

  const key = process.env.GEMINI_API_KEY;
  if (!key) { res.status(200).json({ reply: null, noKey: true }); return; }

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch { body = {}; } }
  const messages = (body && Array.isArray(body.messages)) ? body.messages : [];
  const context = (body && body.context) || '';

  const system =
`Eres el "Asistente de Soporte Técnico" del IGSS Consultorio Chiquimula. Ayudas al personal de salud (médicos, enfermería y personal administrativo) a resolver problemas con su computadora, impresora, internet o correo. Muchas de estas personas NO son técnicas y a algunas les cuesta usar la computadora.

Forma de hablar (muy importante):
- Habla en español sencillo, cálido y respetuoso, como le explicarías a alguien que casi no usa la computadora. Trata a la persona de "usted".
- NO uses palabras técnicas (por ejemplo: driver, controlador, IP, DNS, router, switch, dominio, Active Directory, caché, cmd, ipconfig, puerto, firmware, servidor). Si una es inevitable, explícala con palabras comunes entre paréntesis.
- Usa frases cortas. Da como máximo 3 o 4 pasos a la vez, numerados, y describe lo que la persona VE en la pantalla (por ejemplo: "el botón verde que dice Aceptar", "la figura de la impresora abajo a la derecha").
- Solo pide acciones sencillas y seguras: revisar cables, apagar y encender, cerrar y abrir un programa, revisar papel o tinta.
- NO pidas instalar programas o controladores, cambiar configuraciones del sistema, usar la ventana de comandos ni nada que requiera permisos de administrador. En esos casos, explica en una frase que eso lo hace el técnico y registra el ticket.
- Si la persona no entiende o el problema sigue, no insistas con más pasos: ofrece registrar el ticket.

Reglas:
- Responde SIEMPRE en español.
- Apóyate PRIMERO en la BASE DE CONOCIMIENTOS que se te proporciona. Si no cubre el caso, usa tu conocimiento general de soporte informático (Windows, Office, redes, impresoras, correo), sin inventar datos internos específicos de la institución.
- Puedes responder preguntas y definiciones (por ejemplo "¿cómo veo mi IP?", "¿qué es la RAM?").
- Nunca pidas ni manejes contraseñas, códigos ni datos sensibles.
- Si el usuario pide registrar/crear un ticket, o si el problema es complejo o no se resuelve tras tus indicaciones, agrega al FINAL de tu respuesta, en una línea aparte, EXACTAMENTE este formato:
REGISTRAR_TICKET: <categoria> | <descripción breve del problema>
Categorías válidas: Red o internet, Impresora, Correo electrónico, Acceso a sistemas, Falla de equipo, Software, Otro.
Usa esa línea solo cuando de verdad corresponda registrar el ticket; el resto del tiempo, no la incluyas.`;

  const contents = messages.map(m => ({
    role: m.role === 'user' ? 'user' : 'model',
    parts: [{ text: String(m.text || '') }]
  }));

  const payload = {
    system_instruction: { parts: [{ text: system + '\n\nBASE DE CONOCIMIENTOS RELEVANTE:\n' + context }] },
    contents,
    // El modelo usa parte del límite para "pensar"; con 700 se cortaban las respuestas.
    generationConfig: { temperature: 0.4, maxOutputTokens: 4096 }
  };

  try {
    const model = process.env.GEMINI_MODEL || 'gemini-3.6-flash';
    const url = 'https://generativelanguage.googleapis.com/v1beta/models/' + model + ':generateContent?key=' + key;
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await r.json();
    if (data.error) { res.status(200).json({ reply: null, error: data.error.message }); return; }
    const cand = (data.candidates && data.candidates[0]) || {};
    const parts = (cand.content && Array.isArray(cand.content.parts)) ? cand.content.parts : [];
    let reply = parts.filter(p => typeof p.text === 'string' && !p.thought).map(p => p.text).join('').trim();
    // Si aun así se cortó por longitud, se recorta hasta la última oración completa
    if (reply && cand.finishReason === 'MAX_TOKENS') {
      // último final de oración real (no el punto de un número de paso como "3.")
      let cut = -1; const re = /[^\d\s][.!?](?=\s|$)/g; let m;
      while ((m = re.exec(reply)) !== null) cut = m.index + 1;
      if (cut > 40) reply = reply.slice(0, cut + 1);
      reply += '\n\nSi necesita más ayuda, cuénteme y seguimos paso a paso.';
    }
    res.status(200).json({ reply: reply || null, finish: cand.finishReason || null });
  } catch (e) {
    res.status(200).json({ reply: null, error: String(e) });
  }
}
