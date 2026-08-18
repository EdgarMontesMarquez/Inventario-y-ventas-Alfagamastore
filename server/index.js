const express = require('express');
const cors = require('cors');
const cron = require('node-cron');
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const API_SECRET_KEY = process.env.API_SECRET_KEY || 'alfagama_secret_2026';

// 1. Inicialización de Firebase Admin SDK
try {
  let serviceAccount;
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    // Si se pasa como variable de entorno en texto JSON (ideal para Render)
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    // Si se tiene como archivo local en desarrollo
    try {
      serviceAccount = require('./serviceAccountKey.json');
    } catch (err) {
      console.warn('⚠️ No se encontró serviceAccountKey.json ni FIREBASE_SERVICE_ACCOUNT.');
    }
  }

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('✅ Firebase Admin SDK inicializado correctamente.');
  }
} catch (e) {
  console.error('❌ Error al inicializar Firebase Admin:', e.message);
}

// 2. Inicialización de cliente Supabase
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://kpgkoltwzorznfshwwiv.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.warn('⚠️ Falta la variable SUPABASE_SERVICE_ROLE_KEY en el entorno.');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY || '');

/**
 * Función principal para revisar cartera y enviar notificaciones push
 */
async function checkAndSendCollectionNotifications() {
  console.log(`[${new Date().toISOString()}] 🔍 Iniciando revisión de créditos y cartera...`);

  try {
    // Consultar todos los créditos activos con sus cuotas
    const { data: credits, error } = await supabase
      .from('credits')
      .select('*, credit_installments(*)')
      .neq('status', 'finalizado');

    if (error) {
      console.error('❌ Error al consultar créditos en Supabase:', error.message);
      return { error: error.message };
    }

    if (!credits || credits.length === 0) {
      console.log('ℹ️ No hay créditos activos registrados.');
      return { message: 'Sin créditos activos' };
    }

    const now = new Date();
    // Normalizar a formato YYYY-MM-DD en hora local de Colombia (UTC-5)
    const todayStr = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota' }).format(now);
    const todayDate = new Date(`${todayStr}T00:00:00Z`);

    const dueTodayList = [];
    const overdueList = [];

    let totalDueTodayAmount = 0;
    let totalOverdueAmount = 0;

    for (const credit of credits) {
      const installments = credit.credit_installments || [];
      for (const inst of installments) {
        const quotaVal = Number(inst.amount) || 0;
        const paidVal = Number(inst.paid_amount) || 0;
        const isPaid = inst.is_paid === true || paidVal >= quotaVal;

        if (isPaid) continue;

        const pendingQuota = quotaVal - paidVal;
        const dueDateStr = String(inst.due_date).split('T')[0];
        const dueDate = new Date(`${dueDateStr}T00:00:00Z`);

        const diffTime = todayDate.getTime() - dueDate.getTime();
        const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

        if (diffDays === 0) {
          dueTodayList.push({
            clientName: credit.customer_name || 'Cliente',
            clientPhone: credit.customer_phone || '',
            quotaNumber: inst.number,
            amount: pendingQuota,
            creditId: credit.id,
          });
          totalDueTodayAmount += pendingQuota;
        } else if (diffDays > 0) {
          overdueList.push({
            clientName: credit.customer_name || 'Cliente',
            clientPhone: credit.customer_phone || '',
            quotaNumber: inst.number,
            amount: pendingQuota,
            daysInArrears: diffDays,
            dueDate: dueDateStr,
            creditId: credit.id,
          });
          totalOverdueAmount += pendingQuota;
        }
      }
    }

    console.log(`📊 Balance: ${dueTodayList.length} cuotas para hoy ($${totalDueTodayAmount.toLocaleString('es-CO')}), ${overdueList.length} cuotas en mora ($${totalOverdueAmount.toLocaleString('es-CO')}).`);

    // Si no hay cobros para hoy ni mora, no enviamos notificación para no hacer spam
    if (dueTodayList.length === 0 && overdueList.length === 0) {
      console.log('✨ Cartera al día y sin cobros para hoy.');
      return { message: 'Cartera al día y sin cobros programados para hoy' };
    }

    // Consultar los tokens FCM de los administradores y dispositivos registrados
    const tokensSet = new Set();

    // 1. Desde profiles
    try {
      const { data: adminProfiles } = await supabase
        .from('profiles')
        .select('id, full_name, fcm_token, role')
        .not('fcm_token', 'is', null);

      (adminProfiles || []).forEach(p => {
        if (p.fcm_token && typeof p.fcm_token === 'string' && p.fcm_token.trim().length > 10) {
          tokensSet.add(p.fcm_token.trim());
        }
      });
    } catch (e) {
      console.warn('⚠️ Error al leer profiles:', e.message);
    }

    // 2. Desde user_device_tokens (si existe)
    try {
      const { data: deviceTokens } = await supabase
        .from('user_device_tokens')
        .select('fcm_token')
        .not('fcm_token', 'is', null);

      (deviceTokens || []).forEach(d => {
        if (d.fcm_token && typeof d.fcm_token === 'string' && d.fcm_token.trim().length > 10) {
          tokensSet.add(d.fcm_token.trim());
        }
      });
    } catch (e) {
      // Ignorar si la tabla no ha sido creada
    }

    const validTokens = Array.from(tokensSet);

    if (validTokens.length === 0) {
      console.log('⚠️ No hay tokens FCM de administradores registrados en la base de datos.');
      return { message: 'No hay dispositivos registrados para recibir notificaciones' };
    }

    // Formatear el texto de la notificación ejecutiva
    const formattedTotalHoy = new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 }).format(totalDueTodayAmount);
    
    let notificationTitle = '🔔 Alfa Gama Store · Cobranza del Día';
    let notificationBody = '';

    if (dueTodayList.length > 0 && overdueList.length > 0) {
      notificationBody = `📅 ${dueTodayList.length} cobro(s) para hoy (${formattedTotalHoy}) · ⚠️ ${overdueList.length} cliente(s) en mora. Toca para ver la lista.`;
    } else if (dueTodayList.length > 0) {
      notificationBody = `📅 Tienes ${dueTodayList.length} cobro(s) programados para hoy por un total de ${formattedTotalHoy}.`;
    } else {
      notificationBody = `⚠️ Atención: Tienes ${overdueList.length} cliente(s) con cuotas vencidas en mora.`;
    }

    const payload = {
      tokens: validTokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        route: '/collection-center',
        due_today_count: String(dueTodayList.length),
        overdue_count: String(overdueList.length),
        total_due_today: String(totalDueTodayAmount),
        total_overdue: String(totalOverdueAmount),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'alfa_gama_cobranza',
          color: '#0D1A33',
        },
      },
    };

    console.log(`📤 Enviando notificación push a ${validTokens.length} dispositivo(s)...`);
    const response = await admin.messaging().sendEachForMulticast(payload);
    console.log(`✅ Resultado del envío: ${response.successCount} exitosas, ${response.failureCount} fallidas.`);

    return {
      success: true,
      dueTodayCount: dueTodayList.length,
      overdueCount: overdueList.length,
      totalDueTodayAmount,
      totalOverdueAmount,
      deliveredDevices: response.successCount,
    };
  } catch (err) {
    console.error('❌ Error no controlado en checkAndSendCollectionNotifications:', err);
    return { error: err.message };
  }
}

// 3. Rutas HTTP de Express
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    app: 'Alfa Gama Store - Notification & Collection Backend',
    time: new Date().toISOString(),
  });
});

// Endpoint de prueba directa para validar si las notificaciones push llegan a los dispositivos
app.post('/api/test-notification', async (req, res) => {
  try {
    const { title, body, token } = req.body;
    let targetTokens = [];

    if (token) {
      targetTokens = [token];
    } else {
      // Recoger todos los tokens disponibles
      const tokensSet = new Set();
      try {
        const { data: profiles } = await supabase.from('profiles').select('fcm_token').not('fcm_token', 'is', null);
        (profiles || []).forEach(p => p.fcm_token && tokensSet.add(p.fcm_token.trim()));
      } catch (_) {}

      try {
        const { data: devices } = await supabase.from('user_device_tokens').select('fcm_token').not('fcm_token', 'is', null);
        (devices || []).forEach(d => d.fcm_token && tokensSet.add(d.fcm_token.trim()));
      } catch (_) {}

      targetTokens = Array.from(tokensSet);
    }

    if (targetTokens.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No hay tokens FCM registrados en la base de datos para enviar la prueba.',
      });
    }

    const payload = {
      tokens: targetTokens,
      notification: {
        title: title || '🧪 Prueba de Notificación · Alfa Gama Store',
        body: body || '¡Hola! Esta es una notificación de prueba para verificar que el sistema push funciona al 100%.',
      },
      data: {
        route: '/collection-center',
        type: 'test',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'alfa_gama_cobranza',
          color: '#0D1A33',
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(payload);
    return res.json({
      success: true,
      totalDevices: targetTokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses,
    });
  } catch (err) {
    console.error('❌ Error en /api/test-notification:', err);
    return res.status(500).json({ error: err.message });
  }
});

// Endpoint para disparar la revisión manualmente o por Webhook externo
app.post('/api/check-credits', async (req, res) => {
  const apiKey = req.headers['x-api-key'] || req.query.apiKey;
  if (apiKey !== API_SECRET_KEY && process.env.NODE_ENV === 'production') {
    return res.status(401).json({ error: 'No autorizado. Se requiere x-api-key válido.' });
  }

  const result = await checkAndSendCollectionNotifications();
  res.json(result);
});

// 4. Programación de Tarea Cron Diaria (A las 8:00 AM hora Colombia)
cron.schedule(
  '0 8 * * *',
  () => {
    console.log('⏰ Ejecutando cron job diario de las 8:00 AM...');
    checkAndSendCollectionNotifications();
  },
  {
    timezone: 'America/Bogota',
  }
);

app.listen(PORT, () => {
  console.log(`🚀 Servidor de notificaciones Alfa Gama Store corriendo en el puerto ${PORT}`);
  console.log(`🕒 Cron programado para todos los días a las 8:00 AM (Zona Horaria: America/Bogota).`);
});
