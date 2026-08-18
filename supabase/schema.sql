-- =======================================================
-- ALFA GAMA STORE - ESQUEMA COMPLETO Y REINICIO DE BD (SUPABASE)
-- URL: https://kpgkoltwzorznfshwwiv.supabase.co
-- =======================================================

-- 1. LIMPIEZA E IDEMPOTENCIA
DROP TRIGGER IF EXISTS trigger_decrement_stock ON public.sale_items;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP FUNCTION IF EXISTS public.handle_new_sale_item();
DROP FUNCTION IF EXISTS public.handle_new_user();

DROP TABLE IF EXISTS public.cash_expenses CASCADE;
DROP TABLE IF EXISTS public.cash_shifts CASCADE;
DROP TABLE IF EXISTS public.credit_installments CASCADE;
DROP TABLE IF EXISTS public.credits CASCADE;
DROP TABLE IF EXISTS public.sale_items CASCADE;
DROP TABLE IF EXISTS public.sales CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.store_settings CASCADE;

-- 2. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 3. TABLA DE PERFILES Y ROLES DE USUARIOS (PROFILES)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(200) NOT NULL DEFAULT 'Administrador Alfa Gama Store',
    role VARCHAR(50) NOT NULL DEFAULT 'super_admin', -- 'super_admin' | 'cajero'
    fcm_token TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sound_on_scan BOOLEAN NOT NULL DEFAULT TRUE,
    auto_print_receipt BOOLEAN NOT NULL DEFAULT TRUE
);

-- Trigger para auto-crear perfil cuando se registre un usuario en Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Administrador Alfa Gama Store'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'super_admin')
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. TABLA DE CONFIGURACIÓN DEL NEGOCIO Y TICKET POS (STORE_SETTINGS)
CREATE TABLE public.store_settings (
    id INT PRIMARY KEY DEFAULT 1,
    store_name VARCHAR(200) NOT NULL DEFAULT 'Alfa Gama Store',
    nit VARCHAR(50) NOT NULL DEFAULT '900.123.456-7',
    phone VARCHAR(30) NOT NULL DEFAULT '300 123 4567',
    address VARCHAR(200) NOT NULL DEFAULT 'Cra 5 #12-34',
    receipt_footer TEXT NOT NULL DEFAULT '¡GRACIAS POR SU COMPRA! Conservar este recibo para cambios',
    sound_on_scan BOOLEAN NOT NULL DEFAULT true,
    auto_print_receipt BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);

-- Insertar registro por defecto si no existe
INSERT INTO public.store_settings (id, store_name, nit, phone, address, receipt_footer)
VALUES (1, 'Alfa Gama Store', '900.123.456-7', '300 123 4567', 'Cra 5 #12-34', '¡GRACIAS POR SU COMPRA! Conservar este recibo para cambios')
ON CONFLICT (id) DO NOTHING;

-- 5. TABLA DE CATEGORÍAS (CATEGORIES)
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. TABLA DE PRODUCTOS E INVENTARIO (PRODUCTS)
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL DEFAULT 'Sin categoría',
    price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    stock INT NOT NULL DEFAULT 0,
    min_stock INT NOT NULL DEFAULT 5,
    unit VARCHAR(20) NOT NULL DEFAULT 'unidad',
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. TABLA DE CLIENTES CON TIPO Y N° DE DOCUMENTO DE IDENTIFICACIÓN (CUSTOMERS)
CREATE TABLE public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    phone VARCHAR(30),
    address VARCHAR(200),
    document_type VARCHAR(20) NOT NULL DEFAULT 'CC', -- 'CC' | 'NIT' | 'CE' | 'Pasaporte'
    document_id VARCHAR(50) NOT NULL UNIQUE,
    credit_limit NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    current_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. TABLA DE REGISTRO DE VENTAS CABECERA (SALES)
CREATE TABLE public.sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'efectivo',
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(200),
    note TEXT,
    receipt_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. TABLA DE DETALLE DE ÍTEMS DE VENTA (SALE_ITEMS)
CREATE TABLE public.sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name VARCHAR(200) NOT NULL,
    qty INT NOT NULL DEFAULT 1,
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00
);

-- 10. TABLA DE CRÉDITOS A CUOTAS E INTERESES (CREDITS)
CREATE TABLE public.credits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    customer_name VARCHAR(200) NOT NULL,
    customer_phone VARCHAR(30),
    customer_address VARCHAR(200),
    products TEXT,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    interest_rate NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    interest_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    installments_count INT NOT NULL DEFAULT 1,
    payment_frequency VARCHAR(30) DEFAULT 'mensual',
    status VARCHAR(30) NOT NULL DEFAULT 'activo',
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 11. TABLA DE CUOTAS Y ABONOS DE CRÉDITOS (CREDIT_INSTALLMENTS)
CREATE TABLE public.credit_installments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    credit_id UUID NOT NULL REFERENCES public.credits(id) ON DELETE CASCADE,
    number INT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    paid_at TIMESTAMP WITH TIME ZONE,
    payment_method VARCHAR(50),
    notes TEXT,
    receipt_image_url TEXT
);

-- 12. TABLA DE TURNOS Y ARQUEOS DE CAJA (CASH_SHIFTS)
CREATE TABLE IF NOT EXISTS public.cash_shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_name VARCHAR(200) NOT NULL DEFAULT 'Empleado',
    initial_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cash_sales NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cash_credits NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_expenses NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    expected_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    actual_amount NUMERIC(12, 2),
    difference NUMERIC(12, 2),
    status VARCHAR(30) NOT NULL DEFAULT 'open', -- 'open' | 'closed'
    opened_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    closed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

-- 13. TABLA DE GASTOS Y EGRESOS MENORES DE CAJA (CASH_EXPENSES)
CREATE TABLE IF NOT EXISTS public.cash_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id UUID REFERENCES public.cash_shifts(id) ON DELETE CASCADE,
    description VARCHAR(255) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 14. TABLA DE CARGOS EXTRAS Y RECARGOS A CRÉDITOS (CREDIT_CHARGES)
CREATE TABLE IF NOT EXISTS public.credit_charges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    credit_id UUID NOT NULL REFERENCES public.credits(id) ON DELETE CASCADE,
    concept VARCHAR(255) NOT NULL, -- Ej: 'Recargo por mora', 'Producto adicional', 'Flete', 'Ajuste administrativo'
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    distribution_method VARCHAR(50) NOT NULL DEFAULT 'distribute_remaining', -- 'distribute_remaining' | 'add_installment' | 'next_installment'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by VARCHAR(200) DEFAULT 'Administrador',
    notes TEXT
);

-- =======================================================
-- ÍNDICES DE BÚSQUEDA RÁPIDA (PERFORMANCE & SEARCH)
-- =======================================================
CREATE INDEX IF NOT EXISTS idx_customers_doc_id ON public.customers(document_id);
CREATE INDEX IF NOT EXISTS idx_credits_customer_id ON public.credits(customer_id);
CREATE INDEX IF NOT EXISTS idx_credits_customer_phone ON public.credits(customer_phone);
CREATE INDEX IF NOT EXISTS idx_credit_charges_credit_id ON public.credit_charges(credit_id);

-- =======================================================
-- TRIGGER AUTOMÁTICO: DESCONTAR INVENTARIO EN CADA VENTA
-- =======================================================
CREATE OR REPLACE FUNCTION public.handle_new_sale_item()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.products
    SET stock = GREATEST(0, stock - NEW.qty),
        updated_at = NOW()
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_decrement_stock
AFTER INSERT ON public.sale_items
FOR EACH ROW EXECUTE FUNCTION public.handle_new_sale_item();

-- =======================================================
-- POLÍTICAS DE SEGURIDAD NATIVAS (ROW LEVEL SECURITY - RLS)
-- =======================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_expenses ENABLE ROW LEVEL SECURITY;

-- Políticas para usuarios autenticados del sistema ERP
CREATE POLICY "Allow authenticated access to profiles" ON public.profiles FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to store_settings" ON public.store_settings FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to categories" ON public.categories FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to products" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to customers" ON public.customers FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to sales" ON public.sales FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to sale_items" ON public.sale_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to credits" ON public.credits FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to credit_installments" ON public.credit_installments FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to credit_charges" ON public.credit_charges FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to cash_shifts" ON public.cash_shifts FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated access to cash_expenses" ON public.cash_expenses FOR ALL USING (auth.role() = 'authenticated');

-- POLÍTICAS PÚBLICAS DE LECTURA (Permite consultar estado de cuenta en la web sin login)
CREATE POLICY "Allow public read access to customers" ON public.customers FOR SELECT USING (true);
CREATE POLICY "Allow public read access to credits" ON public.credits FOR SELECT USING (true);
CREATE POLICY "Allow public read access to credit_installments" ON public.credit_installments FOR SELECT USING (true);
CREATE POLICY "Allow public read access to credit_charges" ON public.credit_charges FOR SELECT USING (true);

-- 15. TABLA DE DISPOSITIVOS Y TOKENS FCM PUSH (USER_DEVICE_TOKENS)
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT UNIQUE NOT NULL,
    platform VARCHAR(50) DEFAULT 'web',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated access to user_device_tokens" ON public.user_device_tokens FOR ALL USING (auth.role() = 'authenticated');

