# Alfa Gama Store ERP (Inventory and Sales App)

Este es un sistema integral de punto de venta (POS) y ERP desarrollado con **Flutter** para la gestión eficiente de Alfa Gama Store.

## Características Principales

La aplicación cuenta con una arquitectura modular enfocada en funcionalidades clave para la operación del negocio:

- 🔐 **Autenticación (Auth)**: Gestión segura de acceso para usuarios del sistema.
- 📊 **Panel Principal (Dashboard)**: Vista general con métricas importantes y accesos rápidos.
- 📦 **Inventario (Inventory)**: Control detallado de productos, existencias y movimientos.
- 🛒 **Ventas (Sales)**: Procesamiento de transacciones, carrito de compras y facturación.
- 👥 **Clientes (Customers)**: Registro y seguimiento de la base de clientes.
- 💳 **Créditos (Credits)**: Gestión de cuentas por cobrar y financiamientos de clientes.
- 💵 **Turnos de Caja (Cash Shift)**: Control de apertura, cierres y movimientos de efectivo.
- 📈 **Reportes (Reports)**: Generación de estadísticas y reportes de rendimiento.
- ⚙️ **Configuración (Settings)**: Ajustes generales de la aplicación y del negocio.
- 👤 **Usuarios (Users)**: Administración de roles y permisos para el personal.

## Requisitos Previos

Antes de ejecutar este proyecto, asegúrate de tener instalado:
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-dart)
- Un entorno de desarrollo (Android Studio, VS Code, etc.)

## Variables de Entorno

Este proyecto utiliza **Supabase** como backend. Para que el proyecto funcione correctamente, debes crear un archivo llamado `.env` en la raíz del proyecto (este archivo es ignorado por Git por seguridad) y agregar las siguientes credenciales que obtendrás desde el panel de tu proyecto en Supabase:

```env
# Configuración para el Portal Web (Vite / React)
VITE_SUPABASE_URL=tu_url_de_supabase
VITE_SUPABASE_ANON_KEY=tu_anon_key_de_supabase

# Configuración para Flutter ERP
SUPABASE_URL=tu_url_de_supabase
SUPABASE_ANON_KEY=tu_anon_key_de_supabase
```

## Primeros Pasos

Para ejecutar el proyecto localmente, sigue estos pasos:

1. Clona este repositorio.
2. Instala las dependencias del proyecto ejecutando:
   ```bash
   flutter pub get
   ```
3. Crea tu archivo `.env` en la raíz del proyecto basándote en la sección de **Variables de Entorno**.
4. Ejecuta la aplicación en tu dispositivo o emulador:
   ```bash
   flutter run
   ```

## Estructura del Proyecto

El código fuente principal se encuentra en la carpeta `lib/`, la cual sigue una arquitectura basada en características (`features`). Cada módulo dentro de `lib/features/` contiene su propia lógica de presentación, dominio y datos.
