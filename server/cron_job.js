const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// 1. Inicializar Firebase Admin SDK
try {
  let serviceAccount;
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } catch {
      serviceAccount = JSON.parse(Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf8'));
    }
  } else {
    try {
      serviceAccount = require('./serviceAccountKey.json');
    } catch {
      console.error('❌ Falta serviceAccountKey.json o FIREBASE_SERVICE_ACCOUNT');
      process.exit(1);
    }
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ Firebase Admin SDK conectado.');
} catch (e) {
  console.error('❌ Error al inicializar Firebase Admin:', e.message);
  process.exit(1);
}

// 2. Conectar a Supabase
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://kpgkoltwzorznfshwwiv.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwZ2tvbHR3em9yem5mc2h3d2l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NzIwNTcsImV4cCI6MjEwMDI0ODA1N30.0ASHQQ6XM8QXkwaiM3xXVk1vzPYEADQOzqzWu4ANrNk';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function runAutomaticDailyPush() {
  console.log(`[${new Date().toISOString()}] 🚀 Ejecutando revisión automática de cartera...`);

  try {
    const { data: credits, error } = await supabase
      .from('credits')
      .select('*, credit_installments(*)')
      .neq('status', 'finalizado');

    if (error) {
      console.error('❌ Error al consultar créditos:', error.message);
      return;
    }

    if (!credits || credits.length === 0) {
      console.log('ℹ️ No hay créditos activos registrados.');
      return;
    }

    const now = new Date();
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
          dueTodayList.push({ clientName: credit.customer_name, amount: pendingQuota });
          totalDueTodayAmount += pendingQuota;
        } else if (diffDays > 0) {
          overdueList.push({ clientName: credit.customer_name, amount: pendingQuota, daysInArrears: diffDays });
          totalOverdueAmount += pendingQuota;
        }
      }
    }

    console.log(`📊 Balance del día: ${dueTodayList.length} cuotas para hoy, ${overdueList.length} cuotas en mora.`);

    if (dueTodayList.length === 0 && overdueList.length === 0) {
      console.log('✨ Cartera 100% al día y sin cobros programados para hoy. No se emite alerta.');
      return;
    }

    // Recopilar tokens de profiles y user_device_tokens
    const tokensSet = new Set();
    try {
      const { data: profiles } = await supabase.from('profiles').select('fcm_token').not('fcm_token', 'is', null);
      (profiles || []).forEach(p => p.fcm_token && tokensSet.add(p.fcm_token.trim()));
    } catch (_) {}

    try {
      const { data: devices } = await supabase.from('user_device_tokens').select('fcm_token').not('fcm_token', 'is', null);
      (devices || []).forEach(d => d.fcm_token && tokensSet.add(d.fcm_token.trim()));
    } catch (_) {}

    const validTokens = Array.from(tokensSet);
    if (validTokens.length === 0) {
      console.log('⚠️ No hay tokens FCM registrados en Supabase. Abre la app en el teléfono para sincronizar.');
      return;
    }

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

    console.log(`📤 Enviando notificación automática a ${validTokens.length} dispositivo(s)...`);
    const response = await admin.messaging().sendEachForMulticast(payload);
    console.log(`✅ Despachadas con éxito: ${response.successCount} | Fallidas: ${response.failureCount}`);
  } catch (err) {
    console.error('❌ Error en ejecución automática:', err);
  }
}

runAutomaticDailyPush();
