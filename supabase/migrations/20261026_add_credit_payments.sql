-- ==============================================================================
-- MIGRACIÓN: CREACIÓN DE TABLA DE ABONOS HISTÓRICOS (credit_payments)
-- Y MIGRACIÓN DE ABONOS EXISTENTES DESDE credit_installments
-- ==============================================================================

-- 1. Crear tabla credit_payments si no existe
CREATE TABLE IF NOT EXISTS public.credit_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    credit_id UUID NOT NULL REFERENCES public.credits(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    payment_method VARCHAR(50) NOT NULL DEFAULT 'efectivo',
    receipt_image_url TEXT,
    notes TEXT,
    shift_id UUID REFERENCES public.cash_shifts(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Índices para optimizar velocidad de consultas y arqueos
CREATE INDEX IF NOT EXISTS idx_credit_payments_credit_id ON public.credit_payments(credit_id);
CREATE INDEX IF NOT EXISTS idx_credit_payments_payment_date ON public.credit_payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_credit_payments_shift_id ON public.credit_payments(shift_id);

-- 3. Habilitar Row Level Security (RLS) y Políticas
ALTER TABLE public.credit_payments ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'credit_payments' AND policyname = 'Allow authenticated access to credit_payments'
    ) THEN
        CREATE POLICY "Allow authenticated access to credit_payments" 
        ON public.credit_payments FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'credit_payments' AND policyname = 'Allow public read access to credit_payments'
    ) THEN
        CREATE POLICY "Allow public read access to credit_payments" 
        ON public.credit_payments FOR SELECT 
        USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'credit_payments' AND policyname = 'Allow public insert to credit_payments'
    ) THEN
        CREATE POLICY "Allow public insert to credit_payments" 
        ON public.credit_payments FOR INSERT 
        WITH CHECK (true);
    END IF;
END $$;

-- 4. Migración de datos existentes:
-- Si ya existían abonos registrados en credit_installments, migrarlos a credit_payments
-- para que ningún crédito pierda su historial previo.
INSERT INTO public.credit_payments (credit_id, amount, payment_date, payment_method, notes, receipt_image_url)
SELECT 
    ci.credit_id,
    ci.paid_amount,
    COALESCE(ci.paid_at, NOW()),
    COALESCE(ci.payment_method, 'efectivo'),
    COALESCE(NULLIF(ci.notes, ''), 'Abono previo registrado'),
    ci.receipt_image_url
FROM public.credit_installments ci
WHERE ci.paid_amount > 0
  AND NOT EXISTS (
    SELECT 1 FROM public.credit_payments cp WHERE cp.credit_id = ci.credit_id
  );
