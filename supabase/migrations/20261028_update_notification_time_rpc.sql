-- ==============================================================
-- ACTUALIZACIÓN DINÁMICA DE HORA PARA NOTIFICACIONES DE COBRANZA
-- Permite modificar la hora desde la app y reprograma pg_cron
-- ==============================================================

-- 1. Asegurar columna notification_time en public.store_settings
ALTER TABLE public.store_settings 
ADD COLUMN IF NOT EXISTS notification_time VARCHAR(10) NOT NULL DEFAULT '08:00';

-- 2. Función RPC para actualizar la hora y reprogramar pg_cron automáticamente
CREATE OR REPLACE FUNCTION public.update_collection_notification_time(
  new_hour INT,
  new_minute INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, cron, extensions
AS $$
DECLARE
  v_colombia_time VARCHAR(10);
  v_utc_hour INT;
  v_utc_minute INT;
  v_cron_expr TEXT;
  v_job_id BIGINT;
BEGIN
  -- Validar rangos
  IF new_hour < 0 OR new_hour > 23 THEN
    RAISE EXCEPTION 'La hora debe estar entre 0 y 23';
  END IF;

  IF new_minute < 0 OR new_minute > 59 THEN
    RAISE EXCEPTION 'Los minutos deben estar entre 0 y 59';
  END IF;

  -- Formato HH:MM
  v_colombia_time := to_char(new_hour, 'FM00') || ':' || to_char(new_minute, 'FM00');

  -- Convertir Colombia (UTC-5) a UTC para pg_cron
  -- Hora UTC = (Hora Colombia + 5) módulo 24
  v_utc_hour := (new_hour + 5) % 24;
  v_utc_minute := new_minute;

  -- Expresión cron: "minuto hora * * *"
  v_cron_expr := format('%s %s * * *', v_utc_minute, v_utc_hour);

  -- 1. Actualizar configuración en la tabla store_settings
  UPDATE public.store_settings
  SET notification_time = v_colombia_time,
      updated_at = NOW()
  WHERE id = 1;

  -- 2. Eliminar programación anterior de cron si existe
  BEGIN
    PERFORM cron.unschedule('daily-collection-push');
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  -- 3. Programar la nueva hora en pg_cron
  SELECT cron.schedule(
    'daily-collection-push',
    v_cron_expr,
    $cron$
    SELECT net.http_post(
      url := 'https://kpgkoltwzorznfshwwiv.supabase.co/functions/v1/daily-collection-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
    $cron$
  ) INTO v_job_id;

  RETURN jsonb_build_object(
    'success', true,
    'colombia_time', v_colombia_time,
    'utc_cron', v_cron_expr,
    'job_id', v_job_id
  );
END;
$$;

-- 3. Otorgar permisos de ejecución para usuarios autenticados y service_role
GRANT EXECUTE ON FUNCTION public.update_collection_notification_time(INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_collection_notification_time(INT, INT) TO service_role;
