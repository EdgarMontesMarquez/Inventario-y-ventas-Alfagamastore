const admin = require('firebase-admin');

// Inicializar Firebase Admin SDK con la clave guardada
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

console.log('✅ Conectado a Firebase proyecto:', serviceAccount.project_id);

async function sendDirect(token) {
  if (!token || token.length < 10) {
    console.error('Debes proporcionar un token FCM válido.');
    return;
  }

  console.log(`🚀 Enviando notificación de prueba al token: ${token.substring(0, 25)}...`);

  const message = {
    token: token.trim(),
    notification: {
      title: '🔔 Alfa Gama Store · Prueba Automatizada',
      body: '¡Hola! La conexión de notificaciones push está funcionando al 100% en tu teléfono.',
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
    const response = await admin.messaging().send(message);
    console.log('\n================ RESULTADO ================');
    console.log('✅ NOTIFICACIÓN ENTREGADA CON ÉXITO');
    console.log('ID Mensaje Firebase:', response);
    console.log('===========================================\n');
  } catch (err) {
    console.error('\n❌ ERROR AL ENVIAR:', err.message);
  }
}

// Obtener token del argumento de línea de comandos si se pasa
const cliToken = process.argv[2];
if (cliToken) {
  sendDirect(cliToken);
} else {
  console.log('Pasa el token como argumento: node server/send_to_token.js <TU_FCM_TOKEN>');
}
