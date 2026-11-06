-- =================================================================================
-- MIGRACIÓN DE REPARACIÓN DE CUOTAS E HISTORIAL DE ABONOS
-- 1. Limpia textos repetidos 'Abono: $...' en credit_payments.notes y credit_installments.notes
-- 2. Sincroniza pagos faltantes en credit_payments desde cuotas pagadas con fecha (paid_at)
-- 3. Restaura las cuotas que fueron alteradas en cascada (paid_amount > 0 y paid_at IS NULL)
--    asignando cada abono cronológico de credit_payments a su cuota correspondiente
-- =================================================================================

-- 1. Limpiar textos repetidos 'Abono: $...' y 'Abono previo registrado' en credit_payments y credit_installments
UPDATE public.credit_payments
SET notes = TRIM(
  REGEXP_REPLACE(
    REGEXP_REPLACE(COALESCE(notes, ''), 'Abono:\s*\$[0-9.,]+\s*', '', 'gi'),
    '^Abono previo registrado$', '', 'i'
  )
)
WHERE notes ~* 'Abono:\s*\$[0-9.,]+' OR notes ~* '^Abono previo registrado$';

UPDATE public.credit_installments
SET notes = TRIM(
  REGEXP_REPLACE(
    REGEXP_REPLACE(COALESCE(notes, ''), 'Abono:\s*\$[0-9.,]+\s*', '', 'gi'),
    '^Abono previo registrado$', '', 'i'
  )
)
WHERE notes ~* 'Abono:\s*\$[0-9.,]+' OR notes ~* '^Abono previo registrado$';

-- 2. Insertar en credit_payments los abonos de cuotas que tienen paid_at pero no estaban en credit_payments
INSERT INTO public.credit_payments (
  credit_id,
  amount,
  payment_date,
  payment_method,
  receipt_image_url,
  notes,
  created_at
)
SELECT
  ci.credit_id,
  ci.paid_amount,
  ci.paid_at,
  CASE WHEN ci.payment_method IS NULL OR TRIM(ci.payment_method) = '' THEN 'efectivo' ELSE ci.payment_method END,
  ci.receipt_image_url,
  COALESCE(ci.notes, ''),
  ci.paid_at
FROM public.credit_installments ci
WHERE ci.paid_amount > 0
  AND ci.paid_at IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.credit_payments cp
    WHERE cp.credit_id = ci.credit_id
      AND ABS(cp.amount - ci.paid_amount) < 0.01
      AND ABS(EXTRACT(EPOCH FROM (cp.payment_date - ci.paid_at))) < 120
  );

-- 3. Restaurar cuotas de créditos que sufrieron distribución en cascada (paid_amount > 0 y paid_at IS NULL)
DO $$
DECLARE
  rec_credit RECORD;
  rec_inst RECORD;
  rec_pay RECORD;
  v_idx INT;
BEGIN
  FOR rec_credit IN
    SELECT DISTINCT c.id
    FROM public.credits c
    JOIN public.credit_installments ci ON ci.credit_id = c.id
    WHERE ci.paid_amount > 0 AND ci.paid_at IS NULL
      AND EXISTS (SELECT 1 FROM public.credit_payments cp WHERE cp.credit_id = c.id)
  LOOP
    -- Primero reiniciar todas las cuotas de este crédito a 0
    UPDATE public.credit_installments
    SET paid_amount = 0,
        is_paid = false,
        paid_at = NULL,
        payment_method = '',
        notes = '',
        receipt_image_url = NULL
    WHERE credit_id = rec_credit.id;

    -- Asignar cada pago real (en orden cronológico) a la cuota N° correspondiente
    v_idx := 1;
    FOR rec_pay IN
      SELECT amount, payment_date, payment_method, notes, receipt_image_url
      FROM public.credit_payments
      WHERE credit_id = rec_credit.id
      ORDER BY payment_date ASC, created_at ASC
    LOOP
      UPDATE public.credit_installments
      SET paid_amount = rec_pay.amount,
          is_paid = (rec_pay.amount >= amount AND amount > 0),
          paid_at = rec_pay.payment_date,
          payment_method = COALESCE(rec_pay.payment_method, 'efectivo'),
          notes = COALESCE(rec_pay.notes, ''),
          receipt_image_url = rec_pay.receipt_image_url
      WHERE credit_id = rec_credit.id
        AND number = v_idx;

      v_idx := v_idx + 1;
    END LOOP;
  END LOOP;
END $$;

