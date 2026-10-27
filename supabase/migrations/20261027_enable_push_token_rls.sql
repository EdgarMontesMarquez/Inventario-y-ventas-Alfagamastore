-- ==============================================================
-- MIGRACIÓN: PERMISOS PARA REGISTRO DE TOKENS PUSH DE DISPOSITIVOS
-- Permite que los teléfonos guarden y actualicen su token FCM
-- ==============================================================

-- 1. Asegurar políticas de inserción y actualización en user_device_tokens
DROP POLICY IF EXISTS "Allow public insert to user_device_tokens" ON public.user_device_tokens;
CREATE POLICY "Allow public insert to user_device_tokens" 
ON public.user_device_tokens 
FOR INSERT 
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public update to user_device_tokens" ON public.user_device_tokens;
CREATE POLICY "Allow public update to user_device_tokens" 
ON public.user_device_tokens 
FOR UPDATE 
USING (true);

-- 2. Asegurar que fcm_token sea accesible para lectura
DROP POLICY IF EXISTS "Allow public read access to user_device_tokens" ON public.user_device_tokens;
CREATE POLICY "Allow public read access to user_device_tokens" 
ON public.user_device_tokens 
FOR SELECT 
USING (true);
