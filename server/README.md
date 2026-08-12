# Backend de Notificaciones Push y Cobranza - Alfa Gama Store

Este servidor en **Node.js** se encarga de analizar diariamente la cartera en Supabase, calcular qué cuotas vencen hoy y qué clientes están en mora (con sus días de retraso exactos), y enviar una notificación push consolidada a los teléfonos de los administradores a través de **Firebase Cloud Messaging (FCM)**.

---

## 📁 Contenido de esta carpeta (`server/`)

- `index.js`: Código del servidor Express, consultas de cartera a Supabase, lógica de mora y cron job diario a las 8:00 AM (Colombia).
- `package.json`: Dependencias de Node.js (`firebase-admin`, `@supabase/supabase-js`, `node-cron`, `express`).
- `.env.example`: Plantilla de variables de entorno requeridas.

---

## 🚀 Despliegue en Render (Paso a Paso)

### 1. Subir esta carpeta a GitHub
Puedes crear un repositorio en GitHub llamado `alfa-gama-notifications-server` y subir los archivos de esta carpeta `server/` (o subir el repositorio principal y especificar `Root Directory: server` en Render).

### 2. Crear el Servicio Web en Render
1. Entra a [dashboard.render.com](https://dashboard.render.com/) e inicia sesión.
2. Haz clic en **"New +"** > **"Web Service"**.
3. Conecta tu repositorio de GitHub.
4. Completa la configuración:
   - **Name**: `alfagama-notifications`
   - **Region**: Oregon (US West) o Ohio (US East)
   - **Branch**: `main`
   - **Root Directory**: `server` *(déjalo vacío si creaste un repo exclusivo solo con esta carpeta)*
   - **Runtime**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node index.js`
   - **Plan**: `Free`

### 3. Configurar las Variables de Entorno en Render
En la sección **"Environment Variables"** de tu servicio en Render, agrega las siguientes claves:

| Variable | Valor / Dónde encontrarla |
| :--- | :--- |
| `NODE_ENV` | `production` |
| `SUPABASE_URL` | `https://xwhqymuvzfxwsvtggzts.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | En Supabase > **Project Settings** ⚙️ > **API** > Clave **`service_role` (secret)** |
| `API_SECRET_KEY` | Cualquier clave secreta que elijas (ej: `alfagama_secret_2026`) |
| `FIREBASE_SERVICE_ACCOUNT` | Abre el archivo `.json` que descargaste de Firebase, copia **todo su contenido** y pégalo aquí. |

5. Haz clic en **"Deploy Web Service"**. ¡Listo! Tu backend estará activo y ejecutará la revisión de cartera todos los días a las 8:00 AM.

---

## 🧪 Pruebas Locales (Opcional)

Si deseas probarlo en tu computador antes de subirlo:

1. Abre una terminal dentro de esta carpeta `server/`:
   ```bash
   cd server
   npm install
   ```
2. Renombra tu archivo descargado de Firebase como `serviceAccountKey.json` y colócalo dentro de esta carpeta `server/`.
3. Crea un archivo `.env` basado en `.env.example`.
4. Inicia el servidor:
   ```bash
   node index.js
   ```
5. En otra terminal o desde tu navegador / Postman puedes disparar una prueba inmediata llamando a:
   ```bash
   curl -X POST http://localhost:3000/api/check-credits
   ```
