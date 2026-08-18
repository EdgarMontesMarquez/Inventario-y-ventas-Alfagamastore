const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');

// 1. Inicializar Firebase Admin SDK con la clave guardada
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

console.log('✅ Firebase Admin SDK conectado a proyecto:', serviceAccount.project_id);

// 2. Conectar a Supabase
const SUPABASE_URL = 'https://kpgkoltwzorznfshwwiv.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwZ2tvbHR3em9yem5mc2h3d2l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NzIwNTcsImV4cCI6MjEwMDI0ODA1N30.0ASHQQ6XM8QXkwaiM3xXVk1vzPYEADQOzqzWu4ANrNk';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runTest() {
  console.log('\n🔍 1. Buscando tokens de dispositivos en Supabase...');
  
  const tokensSet = new Set();
  
  // Buscar en profiles
  try {
    const { data: profiles, error: pErr } = await supabase
      .from('profiles')
      .select('id, full_name, fcm_token')
      .not('fcm_token', 'is', null);

    if (pErr) console.warn('Aviso al leer profiles:', pErr.message);
    (profiles || []).forEach(p => {
      if (p.fcm_token && p.fcm_token.length > 10) {
        console.log(`📱 Token encontrado en perfil [${p.full_name || p.id}]:`, p.fcm_token.substring(0, 25) + '...');
        tokensSet.add(p.fcm_token.trim());
      }
    });
  } catch (e) {
    console.warn(e.message);
  }

  // Buscar en user_device_tokens
  try {
    const { data: devices, error: dErr } = await supabase
      .from('user_device_tokens')
      .select('user_id, fcm_token, platform')
      .not('fcm_token', 'is', null);

    if (dErr) console.warn('Aviso al leer user_device_tokens:', dErr.message);
    (devices || []).forEach(d => {
      if (d.fcm_token && d.fcm_token.length > 10) {
        console.log(`📱 Token encontrado en dispositivo [${d.platform}]:`, d.fcm_token.substring(0, 25) + '...');
        tokensSet.add(d.fcm_token.trim());
      }
    });
  } catch (e) {
    console.warn(e.message);
  }

  const validTokens = Array.from(tokensSet);

  if (validTokens.length === 0) {
    console.log('\n⚠️ NO SE ENCONTRARON TOKENS GUARDADOS EN SUPABASE AÚN.');
    console.log('👉 Abre la app en tu teléfono > Ajustes > Diagnóstico de Notificaciones Push > Toca "Re-sincronizar".');
    return;
  }

  console.log(`\n🚀 2. Enviando notificación push automática a ${validTokens.length} dispositivo(s)...`);

  const payload = {
    tokens: validTokens,
    notification: {
      title: '🔔 Alfa Gama Store · Prueba Automatizada',
      body: '¡Excelente! La conexión de notificaciones push está funcionando al 100%.',
    },
    data: {
      route: '/collection-center',
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

  try {
    const response = await admin.messaging().sendEachForMulticast(payload);
    console.log('\n================ RESULTADO DEL ENVÍO ================');
    console.log(`✅ Entregas Exitosas: ${response.successCount}`);
    console.log(`❌ Entregas Fallidas: ${response.failureCount}`);
    
    response.responses.forEach((res, idx) => {
      if (res.success) {
        console.log(`  [Dispositivo #${idx + 1}] ID Mensaje: ${res.messageId}`);
      } else {
        console.error(`  [Dispositivo #${idx + 1}] Error:`, res.error?.message);
      }
    });
    console.log('====================================================\n');
  } catch (err) {
    console.error('❌ Error al enviar push via Firebase:', err);
  }
}

runTest();
