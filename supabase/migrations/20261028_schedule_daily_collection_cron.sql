-- ==============================================================
-- PROGRAMACIÓN DIARIA DE COBRANZA EN SUPABASE (PG_CRON + PG_NET)
-- Ejecuta automáticamente la revisión de cartera todos los días a las 8:00 AM (Colombia)
-- ==============================================================

-- 1. Habilitar extensiones de cron y peticiones de red
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Eliminar el cron anterior si existía para evitar duplicados
DO $$
BEGIN
  PERFORM cron.unschedule('daily-collection-push');
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- 3. Programar la ejecución automática a las 8:00 AM hora de Colombia
-- (Zona horaria Colombia: UTC-5 -> 8:00 AM COL = 13:00 UTC)
SELECT cron.schedule(
  'daily-collection-push',
  '0 13 * * *',
  $$
  SELECT net.http_post(
    url := 'https://kpgkoltwzorznfshwwiv.supabase.co/functions/v1/daily-collection-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
