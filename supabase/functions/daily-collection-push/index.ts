// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import admin from "npm:firebase-admin@12.0.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: any) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🚀 Iniciando revisión automática de cartera en Supabase Edge Function...");

    // 1. Inicializar Firebase Admin
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      throw new Error("Variable de entorno FIREBASE_SERVICE_ACCOUNT no configurada en Supabase.");
    }

    let serviceAccount: any;
    try {
      serviceAccount = JSON.parse(serviceAccountRaw);
    } catch {
      serviceAccount = JSON.parse(atob(serviceAccountRaw));
    }

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }

    // 2. Conectar a Supabase usando variables del entorno del proyecto
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 3. Consultar créditos activos y sus cuotas
    const { data: credits, error } = await supabase
      .from("credits")
      .select("*, credit_installments(*)")
      .neq("status", "finalizado");

    if (error) {
      throw new Error(`Error al consultar créditos: ${error.message}`);
    }

    const now = new Date();
    // Normalizar a zona horaria de Colombia (UTC-5)
    const todayStr = new Intl.DateTimeFormat("en-CA", { timeZone: "America/Bogota" }).format(now);
    const todayDate = new Date(`${todayStr}T00:00:00Z`);

    const dueTodayList = [];
    const overdueList = [];
    let totalDueTodayAmount = 0;
    let totalOverdueAmount = 0;

    for (const credit of credits || []) {
      const installments = credit.credit_installments || [];
      for (const inst of installments) {
        const quotaVal = Number(inst.amount) || 0;
        const paidVal = Number(inst.paid_amount) || 0;
        const isPaid = inst.is_paid === true || paidVal >= quotaVal;

        if (isPaid) continue;

        const pendingQuota = quotaVal - paidVal;
        const dueDateStr = String(inst.due_date).split("T")[0];
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

    console.log(`📊 Balance del día: ${dueTodayList.length} cuotas hoy, ${overdueList.length} cuotas en mora.`);

    if (dueTodayList.length === 0 && overdueList.length === 0) {
      return new Response(
        JSON.stringify({ message: "Cartera 100% al día y sin cobros programados para hoy." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Obtener tokens FCM de dispositivos
    const tokensSet = new Set<string>();
    try {
      const { data: profiles } = await supabase.from("profiles").select("fcm_token").not("fcm_token", "is", null);
      (profiles || []).forEach((p: any) => p.fcm_token && tokensSet.add(p.fcm_token.trim()));
    } catch (_) {}

    try {
      const { data: devices } = await supabase.from("user_device_tokens").select("fcm_token").not("fcm_token", "is", null);
      (devices || []).forEach((d: any) => d.fcm_token && tokensSet.add(d.fcm_token.trim()));
    } catch (_) {}

    const validTokens = Array.from(tokensSet);
    if (validTokens.length === 0) {
      return new Response(
        JSON.stringify({ warning: "No hay dispositivos con token FCM registrados para recibir notificaciones." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Preparar mensaje y enviar vía FCM
    const formattedTotalHoy = new Intl.NumberFormat("es-CO", {
      style: "currency",
      currency: "COP",
      maximumFractionDigits: 0,
    }).format(totalDueTodayAmount);

    let notificationTitle = "🔔 Alfa Gama Store · Cobranza del Día";
    let notificationBody = "";

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
        route: "/collection-center",
        due_today_count: String(dueTodayList.length),
        overdue_count: String(overdueList.length),
        total_due_today: String(totalDueTodayAmount),
        total_overdue: String(totalOverdueAmount),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "alfa_gama_cobranza",
          color: "#0D1A33",
        },
      },
    };

    console.log(`📤 Enviando push a ${validTokens.length} dispositivo(s)...`);
    const response = await admin.messaging().sendEachForMulticast(payload);
    console.log(`✅ Resultado del envío: ${response.successCount} exitosas, ${response.failureCount} fallidas.`);

    return new Response(
      JSON.stringify({
        success: true,
        devicesTargeted: validTokens.length,
        successCount: response.successCount,
        failureCount: response.failureCount,
        dueTodayCount: dueTodayList.length,
        overdueCount: overdueList.length,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("❌ Error en Edge Function:", err.message);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
