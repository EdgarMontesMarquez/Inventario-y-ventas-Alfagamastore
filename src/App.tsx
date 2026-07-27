import { useState, useMemo } from 'react'
import type { CSSProperties, ReactNode } from 'react'
import logoImg from '@/imports/logo_compact.png'

// ─── Types ───────────────────────────────────────────────────────────────────

interface Product {
  id: string; name: string; sku: string; price: number; cost: number
  stock: number; category: string; minStock: number
}
interface SaleLine { productId: string; productName: string; qty: number; unitPrice: number }
interface Sale {
  id: string; lines: SaleLine[]; total: number
  paymentMethod: 'efectivo' | 'tarjeta' | 'transferencia'; createdAt: Date; note: string
}
interface CreditInstallment {
  quotaNumber: number; dueDate: Date; quotaValue: number
  paidAmount: number; paidDate: Date | null; paymentMethod: string; notes: string
}
interface Credit {
  id: string; clientName: string; clientPhone: string; clientAddress: string
  clientDocument: string
  products: string; totalSale: number; startDate: Date
  paymentFrequency: 'semanal' | 'quincenal' | 'mensual'
  totalQuotas: number; quotaValue: number
  installments: CreditInstallment[]; generalNotes: string
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const d = (y: number, m: number, day: number) => new Date(y, m - 1, day)
const uid = () => Math.random().toString(36).slice(2, 9)
const fmt = (n: number) =>
  new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 }).format(n)
const fmtDate = (dt: Date) =>
  dt.toLocaleDateString('es-CO', { day: '2-digit', month: '2-digit', year: 'numeric' })
const fmtShortDate = (dt: Date) =>
  dt.toLocaleDateString('es-CO', { day: '2-digit', month: 'short' })
const fmtTime = (dt: Date) =>
  dt.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
const fmtRelDate = (dt: Date) => {
  const now = new Date(); const y2 = new Date(now); y2.setDate(now.getDate() - 1)
  if (dt.toDateString() === now.toDateString()) return 'Hoy'
  if (dt.toDateString() === y2.toDateString()) return 'Ayer'
  return fmtShortDate(dt)
}
const CATEGORIES = ['Abarrotes', 'Lácteos', 'Panadería', 'Limpieza', 'Bebidas', 'Otros']
const PAYMENT_METHODS = ['efectivo', 'tarjeta', 'transferencia'] as const
const FREQ_LABELS: Record<string, string> = {
  semanal: 'Semanal', quincenal: 'Quincenal', mensual: 'Mensual',
}

function instStatus(inst: CreditInstallment): 'pagado' | 'parcial' | 'vencido' | 'pendiente' {
  if (inst.paidAmount >= inst.quotaValue) return 'pagado'
  if (inst.paidAmount > 0) return 'parcial'
  if (inst.dueDate < new Date()) return 'vencido'
  return 'pendiente'
}
function creditStatus(c: Credit): 'al_dia' | 'mora' | 'finalizado' {
  const paid = c.installments.reduce((s, i) => s + i.paidAmount, 0)
  if (paid >= c.totalSale) return 'finalizado'
  if (c.installments.some(i => instStatus(i) === 'vencido')) return 'mora'
  return 'al_dia'
}
function totalPaid(c: Credit) { return c.installments.reduce((s, i) => s + i.paidAmount, 0) }
function pendingBalance(c: Credit) { return Math.max(0, c.totalSale - totalPaid(c)) }
function progressPct(c: Credit) { return Math.min(100, (totalPaid(c) / c.totalSale) * 100) }
function nextDueInstallment(c: Credit): CreditInstallment | null {
  return c.installments.find(i => instStatus(i) !== 'pagado') ?? null
}
function overdueCount(c: Credit) { return c.installments.filter(i => instStatus(i) === 'vencido').length }

function generateInstallments(
  startDate: Date, frequency: 'semanal' | 'quincenal' | 'mensual',
  totalQuotas: number, quotaValue: number
): CreditInstallment[] {
  return Array.from({ length: totalQuotas }, (_, i) => {
    const due = new Date(startDate)
    if (frequency === 'semanal') due.setDate(startDate.getDate() + (i + 1) * 7)
    else if (frequency === 'quincenal') due.setDate(startDate.getDate() + (i + 1) * 15)
    else due.setMonth(startDate.getMonth() + (i + 1))
    return { quotaNumber: i + 1, dueDate: due, quotaValue, paidAmount: 0, paidDate: null, paymentMethod: '', notes: '' }
  })
}

// ─── Seed data ────────────────────────────────────────────────────────────────

const SEED_PRODUCTS: Product[] = [
  { id: 'p1', name: 'Arroz Superior 1kg', sku: 'ARR-001', price: 1850, cost: 1100, stock: 48, category: 'Abarrotes', minStock: 10 },
  { id: 'p2', name: 'Aceite Vegetal 900ml', sku: 'ACE-002', price: 3200, cost: 2100, stock: 3, category: 'Abarrotes', minStock: 8 },
  { id: 'p3', name: 'Leche Entera 1L', sku: 'LEC-003', price: 1650, cost: 980, stock: 22, category: 'Lácteos', minStock: 12 },
  { id: 'p4', name: 'Pan Integral 500g', sku: 'PAN-004', price: 2100, cost: 1300, stock: 7, category: 'Panadería', minStock: 6 },
  { id: 'p5', name: 'Jabón Lavaplatos', sku: 'JAB-005', price: 890, cost: 450, stock: 0, category: 'Limpieza', minStock: 5 },
  { id: 'p6', name: 'Azúcar Blanca 1kg', sku: 'AZU-006', price: 1400, cost: 850, stock: 31, category: 'Abarrotes', minStock: 10 },
  { id: 'p7', name: 'Café Molido 250g', sku: 'CAF-007', price: 4500, cost: 2800, stock: 15, category: 'Bebidas', minStock: 5 },
  { id: 'p8', name: 'Papel Higiénico x4', sku: 'PAP-008', price: 3800, cost: 2200, stock: 2, category: 'Limpieza', minStock: 6 },
]

const today = new Date()
const yesterday = new Date(today); yesterday.setDate(today.getDate() - 1)
const SEED_SALES: Sale[] = [
  { id: 's1', lines: [{ productId: 'p1', productName: 'Arroz Superior 1kg', qty: 3, unitPrice: 1850 }, { productId: 'p3', productName: 'Leche Entera 1L', qty: 2, unitPrice: 1650 }], total: 8850, paymentMethod: 'efectivo', createdAt: new Date(today.getFullYear(), today.getMonth(), today.getDate(), 10, 23), note: '' },
  { id: 's2', lines: [{ productId: 'p7', productName: 'Café Molido 250g', qty: 1, unitPrice: 4500 }], total: 4500, paymentMethod: 'tarjeta', createdAt: new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12, 47), note: 'Cliente frecuente' },
  { id: 's3', lines: [{ productId: 'p6', productName: 'Azúcar Blanca 1kg', qty: 2, unitPrice: 1400 }, { productId: 'p4', productName: 'Pan Integral 500g', qty: 1, unitPrice: 2100 }], total: 4900, paymentMethod: 'transferencia', createdAt: new Date(today.getFullYear(), today.getMonth(), today.getDate(), 14, 5), note: '' },
  { id: 's4', lines: [{ productId: 'p3', productName: 'Leche Entera 1L', qty: 4, unitPrice: 1650 }], total: 6600, paymentMethod: 'efectivo', createdAt: new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 9, 15), note: '' },
]

// Luchy Tolu installments (weekly from 01/06/2026, first due 06/06/2026)
const lucyInst = generateInstallments(d(2026, 6, 1), 'semanal', 13, 246154)
lucyInst[0].paidAmount = 500000; lucyInst[0].paidDate = d(2026, 6, 6); lucyInst[0].paymentMethod = 'efectivo'

// Carlos Mendoza (monthly from 01/04/2026)
const carlosInst = generateInstallments(d(2026, 4, 1), 'mensual', 10, 250000)
carlosInst[0].paidAmount = 250000; carlosInst[0].paidDate = d(2026, 5, 1); carlosInst[0].paymentMethod = 'efectivo'
carlosInst[1].paidAmount = 250000; carlosInst[1].paidDate = d(2026, 6, 1); carlosInst[1].paymentMethod = 'transferencia'
carlosInst[2].paidAmount = 250000; carlosInst[2].paidDate = d(2026, 7, 3); carlosInst[2].paymentMethod = 'efectivo'

// María García (monthly from 01/03/2026)
const mariaInst = generateInstallments(d(2026, 3, 1), 'mensual', 12, 150000)
mariaInst[0].paidAmount = 150000; mariaInst[0].paidDate = d(2026, 4, 2); mariaInst[0].paymentMethod = 'efectivo'
mariaInst[1].paidAmount = 150000; mariaInst[1].paidDate = d(2026, 5, 5); mariaInst[1].paymentMethod = 'efectivo'

const SEED_CREDITS: Credit[] = [
  { id: 'c1', clientName: 'Luchy Tolu', clientPhone: '300 123 4567', clientAddress: 'Cra 5 #12-34', clientDocument: '1098765432', products: 'Televisor, Colchón base cama', totalSale: 3200000, startDate: d(2026, 6, 1), paymentFrequency: 'semanal', totalQuotas: 13, quotaValue: 246154, installments: lucyInst, generalNotes: 'Pagar únicamente los sábados. Conservar comprobante de pago.' },
  { id: 'c2', clientName: 'Carlos Mendoza', clientPhone: '315 987 6543', clientAddress: 'Av. Simón Bolívar #8-21', clientDocument: '80123456', products: 'Nevera Samsung 400L', totalSale: 2500000, startDate: d(2026, 4, 1), paymentFrequency: 'mensual', totalQuotas: 10, quotaValue: 250000, installments: carlosInst, generalNotes: '' },
  { id: 'c3', clientName: 'María García', clientPhone: '321 456 7890', clientAddress: 'Cll 15 #6-78', clientDocument: '52435678', products: 'Lavadora + Secadora LG', totalSale: 1800000, startDate: d(2026, 3, 1), paymentFrequency: 'mensual', totalQuotas: 12, quotaValue: 150000, installments: mariaInst, generalNotes: 'Acordado refinanciación pendiente.' },
]

// ─── Icons ────────────────────────────────────────────────────────────────────

const Ico = ({ d: path, size = 22, stroke = 1.8 }: { d: string; size?: number; stroke?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round">
    <path d={path} />
  </svg>
)

const IconGrid = () => <Ico d="M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z" />
const IconBox = () => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="21 8 21 21 3 21 3 8"/><rect x="1" y="3" width="22" height="5"/><line x1="10" y1="12" x2="14" y2="12"/>
  </svg>
)
const IconReceipt = () => <Ico d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8zM14 2v6h6M16 13H8M16 17H8M10 9H8" />
const IconCreditCard = () => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
    <rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/>
  </svg>
)
const IconPlus = ({ size = 22 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
  </svg>
)
const IconX = ({ size = 20 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
  </svg>
)
const IconSearch = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
  </svg>
)
const IconBack = () => <Ico d="M19 12H5M12 5l-7 7 7 7" size={20} />
const IconUser = () => <Ico d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2M12 11a4 4 0 100-8 4 4 0 000 8z" />
const IconLock = () => <Ico d="M17 11V7a5 5 0 00-10 0v4M5 11h14a2 2 0 012 2v7a2 2 0 01-2 2H5a2 2 0 01-2-2v-7a2 2 0 012-2z" />
const IconCheck = () => <Ico d="M20 6L9 17l-5-5" size={14} stroke={2.5} />
const IconMinus = () => <Ico d="M5 12h14" size={16} stroke={2.5} />
const IconTrash = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/><path d="M10 11v6M14 11v6M9 6V4h6v2"/>
  </svg>
)
const IconHistory = ({ size = 16 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 8v4l3 3" />
    <path d="M3.05 11a9 9 0 1 1 .1 4.5m-.1-4.5H8M3 11V6" />
  </svg>
)
const IconLogout = () => <Ico d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" size={18} />
const IconAlert = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
  </svg>
)

// ─── Shared components ────────────────────────────────────────────────────────

const inputStyle: CSSProperties = {
  width: '100%', background: '#141414', border: '1px solid #252525', borderRadius: 10,
  padding: '11px 12px', color: '#f0f0f0', fontSize: 14,
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 6 }}>{label}</div>
      {children}
    </div>
  )
}

function StockBadge({ stock, minStock }: { stock: number; minStock: number }) {
  const color = stock === 0 ? '#ff3d3d' : stock <= minStock ? '#ff9800' : '#00e676'
  const bg = stock === 0 ? 'rgba(255,61,61,0.12)' : stock <= minStock ? 'rgba(255,152,0,0.12)' : 'rgba(0,230,118,0.10)'
  const label = stock === 0 ? 'Sin stock' : stock <= minStock ? 'Bajo' : 'OK'
  return (
    <span style={{ color, background: bg, fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 600, padding: '2px 7px', borderRadius: 4 }}>
      {stock} · {label}
    </span>
  )
}

function ProgressBar({ pct, color = '#00e676', height = 6 }: { pct: number; color?: string; height?: number }) {
  return (
    <div style={{ background: '#1e1e1e', borderRadius: height, height, overflow: 'hidden' }}>
      <div style={{ height: '100%', width: `${pct}%`, background: color, borderRadius: height, transition: 'width 0.4s ease' }} />
    </div>
  )
}

function StatusBadge({ status }: { status: 'al_dia' | 'mora' | 'finalizado' }) {
  const cfg = {
    al_dia: { label: 'Al día', color: '#00e676', bg: 'rgba(0,230,118,0.12)' },
    mora: { label: 'En mora', color: '#ff3d3d', bg: 'rgba(255,61,61,0.12)' },
    finalizado: { label: 'Finalizado', color: '#448aff', bg: 'rgba(68,138,255,0.12)' },
  }[status]
  return (
    <span style={{ color: cfg.color, background: cfg.bg, fontFamily: 'JetBrains Mono, monospace', fontSize: 10, fontWeight: 700, padding: '3px 8px', borderRadius: 4, letterSpacing: '0.05em', textTransform: 'uppercase' }}>
      {cfg.label}
    </span>
  )
}

function InstStatusBadge({ status }: { status: 'pagado' | 'parcial' | 'vencido' | 'pendiente' }) {
  const cfg = {
    pagado: { label: 'PAGADO', color: '#00e676', bg: 'rgba(0,230,118,0.15)' },
    parcial: { label: 'PARCIAL', color: '#ff9800', bg: 'rgba(255,152,0,0.15)' },
    vencido: { label: 'VENCIDO', color: '#ff3d3d', bg: 'rgba(255,61,61,0.15)' },
    pendiente: { label: 'PENDIENTE', color: '#666', bg: 'rgba(100,100,100,0.12)' },
  }[status]
  return (
    <span style={{ color: cfg.color, background: cfg.bg, fontFamily: 'JetBrains Mono, monospace', fontSize: 9, fontWeight: 700, padding: '2px 6px', borderRadius: 3, letterSpacing: '0.04em', whiteSpace: 'nowrap' }}>
      {cfg.label}
    </span>
  )
}

// ─── Login Screen ─────────────────────────────────────────────────────────────

function LoginScreen({ onLogin }: { onLogin: () => void }) {
  const [user, setUser] = useState('')
  const [pass, setPass] = useState('')
  const [error, setError] = useState(false)
  const [showPass, setShowPass] = useState(false)

  const handleLogin = () => {
    if (user.toLowerCase() === 'admin' && pass === '1234') {
      onLogin()
    } else {
      setError(true)
      setTimeout(() => setError(false), 2000)
    }
  }

  return (
    <div style={{ minHeight: '100dvh', background: '#080808', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '24px 24px 48px' }}>
      {/* Brand */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 48 }}>
        <div style={{ width: 90, height: 90, background: '#fff', borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 20, boxShadow: '0 0 40px rgba(0,230,118,0.15)' }}>
          <img src={logoImg} alt="Alfa Gama Store logo" style={{ width: 72, height: 72, objectFit: 'contain' }} />
        </div>
        <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 20, fontWeight: 700, color: '#f0f0f0', letterSpacing: '0.05em', textAlign: 'center' }}>
          ALFA GAMA STORE
        </div>
        <div style={{ fontFamily: 'DM Sans, sans-serif', fontSize: 13, color: '#555', marginTop: 4, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
          Moda, Calidad y Estilo
        </div>
      </div>

      {/* Form */}
      <div style={{ width: '100%', maxWidth: 380, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ position: 'relative' }}>
          <span style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: '#444', display: 'flex' }}>
            <IconUser />
          </span>
          <input
            value={user}
            onChange={e => setUser(e.target.value)}
            placeholder="Usuario"
            onKeyDown={e => e.key === 'Enter' && handleLogin()}
            style={{ ...inputStyle, paddingLeft: 44, fontSize: 15 }}
          />
        </div>

        <div style={{ position: 'relative' }}>
          <span style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: '#444', display: 'flex' }}>
            <IconLock />
          </span>
          <input
            value={pass}
            onChange={e => setPass(e.target.value)}
            type={showPass ? 'text' : 'password'}
            placeholder="Contraseña"
            onKeyDown={e => e.key === 'Enter' && handleLogin()}
            style={{ ...inputStyle, paddingLeft: 44, paddingRight: 44, fontSize: 15 }}
          />
          <button
            onClick={() => setShowPass(v => !v)}
            style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', color: '#555', cursor: 'pointer', fontSize: 11, fontFamily: 'JetBrains Mono, monospace' }}
          >
            {showPass ? 'OCULTAR' : 'VER'}
          </button>
        </div>

        {error && (
          <div style={{ background: 'rgba(255,61,61,0.12)', border: '1px solid rgba(255,61,61,0.25)', borderRadius: 10, padding: '10px 14px', color: '#ff3d3d', fontSize: 13, textAlign: 'center' }}>
            Usuario o contraseña incorrectos
          </div>
        )}

        <button
          onClick={handleLogin}
          style={{ background: '#00e676', color: '#000', border: 'none', borderRadius: 12, padding: '15px', fontSize: 15, fontWeight: 700, cursor: 'pointer', marginTop: 4, letterSpacing: '0.02em', transition: 'opacity 0.15s' }}
        >
          Ingresar
        </button>

        <div style={{ textAlign: 'center', fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#333', marginTop: 8 }}>
          demo: admin / 1234
        </div>
      </div>

      <div style={{ position: 'absolute', bottom: 24, fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#2a2a2a', letterSpacing: '0.06em' }}>
        "Tu estilo, nuestra pasión"
      </div>
    </div>
  )
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

function DashboardTab({ products, sales, credits }: { products: Product[]; sales: Sale[]; credits: Credit[] }) {
  const todaySales = sales.filter(s => s.createdAt.toDateString() === new Date().toDateString())
  const todayRevenue = todaySales.reduce((a, s) => a + s.total, 0)
  const totalStockValue = products.reduce((a, p) => a + p.price * p.stock, 0)
  const lowStock = products.filter(p => p.stock <= p.minStock && p.stock > 0)
  const outOfStock = products.filter(p => p.stock === 0)
  const totalCreditReceivable = credits.reduce((a, c) => a + pendingBalance(c), 0)
  const creditsInMora = credits.filter(c => creditStatus(c) === 'mora')

  return (
    <div style={{ padding: '20px 16px', display: 'flex', flexDirection: 'column', gap: 16, overflowY: 'auto', flex: 1 }}>
      {/* Header */}
      <div>
        <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 4 }}>
          {new Date().toLocaleDateString('es-CO', { weekday: 'long', day: 'numeric', month: 'long' })}
        </div>
        <div style={{ fontSize: 22, fontWeight: 600 }}>Resumen</div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <StatCard label="Ventas hoy" value={fmt(todayRevenue)} sub={`${todaySales.length} transacciones`} accent="#00e676" />
        <StatCard label="Por cobrar" value={fmt(totalCreditReceivable)} sub={`${credits.filter(c => creditStatus(c) !== 'finalizado').length} créditos activos`} accent="#448aff" />
        <StatCard label="Inventario" value={fmt(totalStockValue)} sub={`${products.length} productos`} accent="#ff9800" />
        <StatCard label="En mora" value={`${creditsInMora.length}`} sub="créditos atrasados" accent={creditsInMora.length > 0 ? '#ff3d3d' : '#555'} />
      </div>

      {/* Stock alerts */}
      {(lowStock.length > 0 || outOfStock.length > 0) && (
        <div style={{ background: '#111', border: '1px solid #222', borderRadius: 12, overflow: 'hidden' }}>
          <div style={{ padding: '12px 14px', borderBottom: '1px solid #1e1e1e', display: 'flex', alignItems: 'center', gap: 8 }}>
            <IconAlert />
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#ff9800' }}>Alertas de stock</span>
          </div>
          {outOfStock.map(p => <AlertRow key={p.id} name={p.name} sku={p.sku} msg="Sin stock" color="#ff3d3d" />)}
          {lowStock.map(p => <AlertRow key={p.id} name={p.name} sku={p.sku} msg={`${p.stock} uds`} color="#ff9800" />)}
        </div>
      )}

      {/* Today's sales */}
      {todaySales.length > 0 && (
        <div style={{ background: '#111', border: '1px solid #222', borderRadius: 12, overflow: 'hidden' }}>
          <div style={{ padding: '12px 14px', borderBottom: '1px solid #1e1e1e' }}>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#555' }}>Ventas de hoy</span>
          </div>
          {todaySales.map((s, i) => (
            <div key={s.id} style={{ padding: '12px 14px', borderBottom: i < todaySales.length - 1 ? '1px solid #1a1a1a' : 'none', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: 13, fontWeight: 500, marginBottom: 2 }}>{s.lines.map(l => l.productName).join(', ').slice(0, 30)}{s.lines.map(l => l.productName).join('').length > 30 ? '…' : ''}</div>
                <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555' }}>{fmtTime(s.createdAt)} · {s.paymentMethod}</div>
              </div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 14, fontWeight: 600, color: '#00e676' }}>{fmt(s.total)}</div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function StatCard({ label, value, sub, accent }: { label: string; value: string; sub: string; accent: string }) {
  return (
    <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '14px 14px 12px' }}>
      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 8 }}>{label}</div>
      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 17, fontWeight: 700, color: accent, marginBottom: 4, lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 11, color: '#444' }}>{sub}</div>
    </div>
  )
}

function AlertRow({ name, sku, msg, color }: { name: string; sku: string; msg: string; color: string }) {
  return (
    <div style={{ padding: '10px 14px', borderBottom: '1px solid #161616', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div>
        <div style={{ fontSize: 13, fontWeight: 500 }}>{name}</div>
        <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555' }}>{sku}</div>
      </div>
      <span style={{ color, background: `${color}18`, fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 600, padding: '2px 8px', borderRadius: 4 }}>{msg}</span>
    </div>
  )
}

// ─── Inventory Tab ────────────────────────────────────────────────────────────

function InventoryTab({ products, onAdd, onUpdate, onDelete }: { products: Product[]; onAdd: (p: Product) => void; onUpdate: (p: Product) => void; onDelete: (id: string) => void }) {
  const [search, setSearch] = useState('')
  const [filterCat, setFilterCat] = useState('Todos')
  const [showForm, setShowForm] = useState(false)
  const [editProduct, setEditProduct] = useState<Product | null>(null)

  const allCategories = ['Todos', ...CATEGORIES]
  const filtered = useMemo(() => products.filter(p => {
    const ms = p.name.toLowerCase().includes(search.toLowerCase()) || p.sku.toLowerCase().includes(search.toLowerCase())
    return ms && (filterCat === 'Todos' || p.category === filterCat)
  }), [products, search, filterCat])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '16px 16px 0', flexShrink: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
          <div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 2 }}>Inventario</div>
            <div style={{ fontSize: 18, fontWeight: 600 }}>{products.length} productos</div>
          </div>
          <button onClick={() => { setEditProduct(null); setShowForm(true) }} style={{ background: '#00e676', color: '#000', border: 'none', borderRadius: 10, padding: '9px 14px', fontWeight: 600, fontSize: 13, display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
            <IconPlus size={16} /> Agregar
          </button>
        </div>
        <div style={{ position: 'relative', marginBottom: 12 }}>
          <span style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: '#444', display: 'flex' }}><IconSearch /></span>
          <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Buscar producto o SKU…" style={{ width: '100%', background: '#111', border: '1px solid #222', borderRadius: 10, padding: '10px 12px 10px 36px', color: '#f0f0f0', fontSize: 14 }} />
        </div>
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 14 }}>
          {allCategories.map(c => (
            <button key={c} onClick={() => setFilterCat(c)} style={{ background: filterCat === c ? '#00e676' : '#111', color: filterCat === c ? '#000' : '#888', border: `1px solid ${filterCat === c ? '#00e676' : '#222'}`, borderRadius: 20, padding: '5px 14px', fontSize: 12, fontWeight: filterCat === c ? 600 : 400, whiteSpace: 'nowrap', cursor: 'pointer' }}>{c}</button>
          ))}
        </div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 16px' }}>
        {filtered.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#333', fontFamily: 'JetBrains Mono, monospace', fontSize: 13, paddingTop: 40 }}>Sin resultados</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {filtered.map(p => (
              <div key={p.id} onClick={() => { setEditProduct(p); setShowForm(true) }} style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '13px 14px', cursor: 'pointer' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
                  <div style={{ flex: 1, paddingRight: 10 }}>
                    <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.name}</div>
                    <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#444' }}>{p.sku} · {p.category}</div>
                  </div>
                  <StockBadge stock={p.stock} minStock={p.minStock} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  {[{ l: 'PRECIO', v: fmt(p.price), c: '#00e676' }, { l: 'COSTO', v: fmt(p.cost), c: '#888' }, { l: 'MARGEN', v: `${Math.round((p.price - p.cost) / p.price * 100)}%`, c: '#448aff' }].map(({ l, v, c }) => (
                    <div key={l}>
                      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', marginBottom: 1 }}>{l}</div>
                      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, fontWeight: 600, color: c }}>{v}</div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
      {showForm && (
        <ProductForm
          initial={editProduct}
          onSave={p => { editProduct ? onUpdate(p) : onAdd(p); setShowForm(false) }}
          onDelete={id => { onDelete(id); setShowForm(false) }}
          onClose={() => setShowForm(false)}
        />
      )}
    </div>
  )
}

function ProductForm({ initial, onSave, onDelete, onClose }: { initial: Product | null; onSave: (p: Product) => void; onDelete: (id: string) => void; onClose: () => void }) {
  const [name, setName] = useState(initial?.name ?? '')
  const [sku, setSku] = useState(initial?.sku ?? '')
  const [price, setPrice] = useState(initial?.price?.toString() ?? '')
  const [cost, setCost] = useState(initial?.cost?.toString() ?? '')
  const [stock, setStock] = useState(initial?.stock?.toString() ?? '')
  const [minStock, setMinStock] = useState(initial?.minStock?.toString() ?? '5')
  const [category, setCategory] = useState(initial?.category ?? 'Abarrotes')
  const [showConfirmDelete, setShowConfirmDelete] = useState(false)
  const valid = name.trim() && sku.trim() && Number(price) > 0
  return (
    <div className="fade-in" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 50, display: 'flex', alignItems: 'flex-end' }}>
      <div className="slide-up" style={{ background: '#0e0e0e', border: '1px solid #222', borderRadius: '20px 20px 0 0', width: '100%', maxHeight: '92vh', overflowY: 'auto', padding: '20px 16px 40px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <div style={{ fontSize: 17, fontWeight: 600 }}>{initial ? 'Editar producto' : 'Nuevo producto'}</div>
          <button onClick={onClose} style={{ background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 8, padding: 8, cursor: 'pointer', display: 'flex' }}><IconX /></button>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <Field label="Nombre"><input value={name} onChange={e => setName(e.target.value)} placeholder="Arroz Superior 1kg" style={inputStyle} /></Field>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="SKU"><input value={sku} onChange={e => setSku(e.target.value)} placeholder="ARR-001" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace', fontSize: 13 }} /></Field>
            <Field label="Categoría"><select value={category} onChange={e => setCategory(e.target.value)} style={{ ...inputStyle, appearance: 'none' }}>{CATEGORIES.map(c => <option key={c}>{c}</option>)}</select></Field>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="Precio"><input value={price} onChange={e => setPrice(e.target.value)} type="number" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace' }} /></Field>
            <Field label="Costo"><input value={cost} onChange={e => setCost(e.target.value)} type="number" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace' }} /></Field>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="Stock actual"><input value={stock} onChange={e => setStock(e.target.value)} type="number" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace' }} /></Field>
            <Field label="Stock mínimo"><input value={minStock} onChange={e => setMinStock(e.target.value)} type="number" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace' }} /></Field>
          </div>
          <button onClick={() => valid && onSave({ id: initial?.id ?? uid(), name: name.trim(), sku: sku.trim().toUpperCase(), price: Number(price), cost: Number(cost), stock: Number(stock) || 0, minStock: Number(minStock) || 5, category })} disabled={!valid} style={{ background: valid ? '#00e676' : '#1a1a1a', color: valid ? '#000' : '#444', border: 'none', borderRadius: 12, padding: 14, fontSize: 15, fontWeight: 600, cursor: valid ? 'pointer' : 'not-allowed', marginTop: 6 }}>
            {initial ? 'Guardar cambios' : 'Agregar producto'}
          </button>
          {initial && (
            <button onClick={() => setShowConfirmDelete(true)} style={{ background: 'rgba(255,61,61,0.08)', color: '#ff3d3d', border: '1px solid rgba(255,61,61,0.15)', borderRadius: 12, padding: 14, fontSize: 15, fontWeight: 600, cursor: 'pointer', marginTop: 4 }}>
              Eliminar producto
            </button>
          )}
        </div>
      </div>

      {showConfirmDelete && (
        <div className="fade-in" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 60, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
          <div className="scale-up" style={{ background: '#0e0e0e', border: '1px solid #222', borderRadius: 16, padding: '20px 24px', width: '100%', maxWidth: 340, textAlign: 'center' }}>
            <div style={{ color: '#ff3d3d', marginBottom: 12, display: 'flex', justifyContent: 'center' }}>
              <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#ff3d3d" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
                <line x1="12" y1="9" x2="12" y2="13"/>
                <line x1="12" y1="17" x2="12.01" y2="17"/>
              </svg>
            </div>
            <div style={{ fontSize: 16, fontWeight: 600, marginBottom: 8, color: '#f0f0f0' }}>¿Eliminar producto?</div>
            <div style={{ fontSize: 13, color: '#888', marginBottom: 20, lineHeight: 1.4 }}>
              Esta acción no se puede deshacer. Se eliminará el producto <strong>{name}</strong> del inventario.
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                onClick={() => setShowConfirmDelete(false)}
                style={{ flex: 1, background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 600, cursor: 'pointer' }}
              >
                Cancelar
              </button>
              <button
                onClick={() => {
                  if (initial) {
                    onDelete(initial.id)
                  }
                  setShowConfirmDelete(false)
                }}
                style={{ flex: 1, background: '#ff3d3d', border: 'none', color: '#000', borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 700, cursor: 'pointer' }}
              >
                Sí, eliminar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Sales Tab ────────────────────────────────────────────────────────────────

function SalesTab({ sales }: { sales: Sale[] }) {
  const sorted = [...sales].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
  const grouped = useMemo(() => {
    const map = new Map<string, Sale[]>()
    sorted.forEach(s => { const k = fmtRelDate(s.createdAt); if (!map.has(k)) map.set(k, []); map.get(k)!.push(s) })
    return Array.from(map.entries())
  }, [sales])
  const totalToday = sales.filter(s => s.createdAt.toDateString() === new Date().toDateString()).reduce((a, s) => a + s.total, 0)
  const pmColor = (m: string) => m === 'efectivo' ? '#00e676' : m === 'tarjeta' ? '#448aff' : '#ff9800'
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '16px 16px 0', flexShrink: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 14 }}>
          <div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 2 }}>Registro de ventas</div>
            <div style={{ fontSize: 18, fontWeight: 600 }}>{sales.length} registros</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 2 }}>Hoy</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 16, fontWeight: 700, color: '#00e676' }}>{fmt(totalToday)}</div>
          </div>
        </div>
        <div style={{ height: 1, background: '#1e1e1e' }} />
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px 16px' }}>
        {grouped.map(([dateLabel, daySales]) => (
          <div key={dateLabel} style={{ marginBottom: 20 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 600, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase' }}>{dateLabel}</span>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#00e676' }}>{fmt(daySales.reduce((a, s) => a + s.total, 0))}</span>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {daySales.map(s => (
                <div key={s.id} style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '13px 14px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 10 }}>
                    <div style={{ flex: 1, paddingRight: 10 }}>
                      {s.lines.map((l, i) => (
                        <div key={i} style={{ fontSize: 13, color: '#c0c0c0', marginBottom: 2 }}>
                          <span style={{ fontFamily: 'JetBrains Mono, monospace', color: '#555', marginRight: 4 }}>{l.qty}×</span>{l.productName}
                        </div>
                      ))}
                    </div>
                    <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 15, fontWeight: 700, color: '#00e676' }}>{fmt(s.total)}</div>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#444' }}>{fmtTime(s.createdAt)}</span>
                    <span style={{ color: pmColor(s.paymentMethod), background: `${pmColor(s.paymentMethod)}18`, fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 600, padding: '2px 8px', borderRadius: 4 }}>{s.paymentMethod}</span>
                  </div>
                  {s.note && <div style={{ marginTop: 8, fontSize: 12, color: '#444', borderTop: '1px solid #1a1a1a', paddingTop: 8 }}>{s.note}</div>}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// ─── New Sale Modal ───────────────────────────────────────────────────────────

function NewSaleModal({ products, onSave, onClose }: { products: Product[]; onSave: (s: Sale) => void; onClose: () => void }) {
  const [lines, setLines] = useState<{ productId: string; qty: number }[]>([])
  const [paymentMethod, setPaymentMethod] = useState<'efectivo' | 'tarjeta' | 'transferencia'>('efectivo')
  const [note, setNote] = useState('')
  const [search, setSearch] = useState('')
  const available = products.filter(p => p.stock > 0)
  const filtered = search ? available.filter(p => p.name.toLowerCase().includes(search.toLowerCase())) : available
  const total = lines.reduce((acc, l) => { const p = products.find(p => p.id === l.productId); return acc + (p ? p.price * l.qty : 0) }, 0)
  const validLines = lines.filter(l => l.productId && l.qty > 0)
  const pmColor = (m: string) => m === 'efectivo' ? '#00e676' : m === 'tarjeta' ? '#448aff' : '#ff9800'

  return (
    <div className="fade-in" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', zIndex: 50, display: 'flex', alignItems: 'flex-end' }}>
      <div className="slide-up" style={{ background: '#0e0e0e', border: '1px solid #222', borderRadius: '20px 20px 0 0', width: '100%', maxHeight: '94vh', overflowY: 'auto', padding: '20px 16px 40px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <div style={{ fontSize: 17, fontWeight: 600 }}>Nueva venta</div>
          <button onClick={onClose} style={{ background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 8, padding: 8, cursor: 'pointer', display: 'flex' }}><IconX /></button>
        </div>
        <div style={{ marginBottom: 16 }}>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Productos</div>
          <div style={{ position: 'relative', marginBottom: 10 }}>
            <span style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: '#444', display: 'flex' }}><IconSearch /></span>
            <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Buscar para agregar…" style={{ width: '100%', background: '#141414', border: '1px solid #222', borderRadius: 8, padding: '9px 10px 9px 30px', color: '#f0f0f0', fontSize: 13 }} />
          </div>
          {search && (
            <div style={{ background: '#141414', border: '1px solid #222', borderRadius: 8, marginBottom: 10, overflow: 'hidden' }}>
              {filtered.slice(0, 5).map(p => (
                <button key={p.id} onClick={() => { const ex = lines.findIndex(l => l.productId === p.id); if (ex >= 0) setLines(prev => prev.map((l, i) => i === ex ? { ...l, qty: l.qty + 1 } : l)); else setLines(prev => [...prev, { productId: p.id, qty: 1 }]); setSearch('') }} style={{ width: '100%', background: 'transparent', border: 'none', borderBottom: '1px solid #1e1e1e', padding: '10px 12px', display: 'flex', justifyContent: 'space-between', cursor: 'pointer', color: '#f0f0f0' }}>
                  <span style={{ fontSize: 13 }}>{p.name}</span>
                  <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#00e676' }}>{fmt(p.price)}</span>
                </button>
              ))}
              {filtered.length === 0 && <div style={{ padding: '10px 12px', fontSize: 13, color: '#444' }}>Sin resultados</div>}
            </div>
          )}
          {lines.map((line, i) => {
            const p = products.find(x => x.id === line.productId)
            if (!p) return null
            return (
              <div key={i} style={{ background: '#141414', border: '1px solid #1e1e1e', borderRadius: 10, padding: '10px 12px', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.name}</div>
                  <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#00e676', marginTop: 2 }}>{fmt(p.price * line.qty)}</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexShrink: 0 }}>
                  <button onClick={() => line.qty > 1 ? setLines(prev => prev.map((l, idx) => idx === i ? { ...l, qty: l.qty - 1 } : l)) : setLines(prev => prev.filter((_, idx) => idx !== i))} style={{ background: '#222', border: 'none', color: '#888', borderRadius: 6, width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}><IconMinus /></button>
                  <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 15, fontWeight: 600, minWidth: 24, textAlign: 'center' }}>{line.qty}</span>
                  <button onClick={() => setLines(prev => prev.map((l, idx) => idx === i ? { ...l, qty: l.qty + 1 } : l))} style={{ background: '#222', border: 'none', color: '#888', borderRadius: 6, width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}><IconPlus size={16} /></button>
                  <button onClick={() => setLines(prev => prev.filter((_, idx) => idx !== i))} style={{ background: 'transparent', border: 'none', color: '#444', padding: 4, cursor: 'pointer', display: 'flex', marginLeft: 2 }}><IconTrash /></button>
                </div>
              </div>
            )
          })}
          {validLines.length === 0 && !search && <div style={{ textAlign: 'center', padding: '20px 0', fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#333' }}>Busca un producto para agregar</div>}
        </div>
        <div style={{ marginBottom: 14 }}>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Método de pago</div>
          <div style={{ display: 'flex', gap: 8 }}>
            {PAYMENT_METHODS.map(m => (
              <button key={m} onClick={() => setPaymentMethod(m)} style={{ flex: 1, background: paymentMethod === m ? `${pmColor(m)}18` : '#141414', color: paymentMethod === m ? pmColor(m) : '#666', border: `1px solid ${paymentMethod === m ? pmColor(m) : '#222'}`, borderRadius: 10, padding: '9px 0', fontSize: 12, fontWeight: 600, cursor: 'pointer', textTransform: 'capitalize' }}>{m}</button>
            ))}
          </div>
        </div>
        <div style={{ marginBottom: 18 }}>
          <Field label="Nota (opcional)"><input value={note} onChange={e => setNote(e.target.value)} placeholder="Cliente frecuente, pedido especial…" style={{ ...inputStyle, background: '#141414' }} /></Field>
        </div>
        <div style={{ background: '#141414', border: '1px solid #222', borderRadius: 12, padding: '14px 16px', marginBottom: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#555', letterSpacing: '0.06em' }}>TOTAL</span>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 22, fontWeight: 700, color: '#00e676' }}>{fmt(total)}</span>
          </div>
        </div>
        <button onClick={() => { if (!validLines.length) return; const saleLines: SaleLine[] = validLines.map(l => { const p = products.find(x => x.id === l.productId)!; return { productId: l.productId, productName: p.name, qty: l.qty, unitPrice: p.price } }); onSave({ id: uid(), lines: saleLines, total, paymentMethod, createdAt: new Date(), note: note.trim() }) }} disabled={validLines.length === 0} style={{ width: '100%', background: validLines.length > 0 ? '#00e676' : '#1a1a1a', color: validLines.length > 0 ? '#000' : '#444', border: 'none', borderRadius: 12, padding: 15, fontSize: 15, fontWeight: 700, cursor: validLines.length > 0 ? 'pointer' : 'not-allowed' }}>
          Registrar venta · {fmt(total)}
        </button>
      </div>
    </div>
  )
}

// ─── Credit Tab ───────────────────────────────────────────────────────────────

function CreditTab({ credits, onAdd, onUpdate }: { credits: Credit[]; onAdd: (c: Credit) => void; onUpdate: (c: Credit) => void }) {
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [showNewForm, setShowNewForm] = useState(false)
  const [showFinalized, setShowFinalized] = useState(false)
  const [search, setSearch] = useState('')

  const selected = credits.find(c => c.id === selectedId) ?? null

  if (selected) {
    return <CreditDetail credit={selected} onBack={() => setSelectedId(null)} onUpdate={onUpdate} />
  }

  const activeCredits = useMemo(() => credits.filter(c => creditStatus(c) !== 'finalizado'), [credits])

  const filteredActive = useMemo(() => {
    return activeCredits.filter(c => {
      const s = search.toLowerCase()
      const nameMatch = c.clientName.toLowerCase().includes(s)
      const docMatch = c.clientDocument ? c.clientDocument.toLowerCase().includes(s) : false
      return nameMatch || docMatch
    })
  }, [activeCredits, search])

  const totalReceivable = credits.reduce((s, c) => s + pendingBalance(c), 0)
  const inMora = credits.filter(c => creditStatus(c) === 'mora').length

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '16px 16px 0', flexShrink: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
          <div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 2 }}>Créditos</div>
            <div style={{ fontSize: 18, fontWeight: 600 }}>{activeCredits.length} activos</div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setShowFinalized(true)} style={{ background: '#1a1a1a', border: '1px solid #222', color: '#888', borderRadius: 10, padding: '9px 12px', fontWeight: 600, fontSize: 13, display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
              <IconHistory size={16} /> Finalizados
            </button>
            <button onClick={() => setShowNewForm(true)} style={{ background: '#448aff', color: '#fff', border: 'none', borderRadius: 10, padding: '9px 14px', fontWeight: 600, fontSize: 13, display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
              <IconPlus size={16} /> Nuevo
            </button>
          </div>
        </div>
        {/* Summary bar */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 14 }}>
          <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 10, padding: '10px 12px' }}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 4 }}>Por cobrar</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 14, fontWeight: 700, color: '#448aff' }}>{fmt(totalReceivable)}</div>
          </div>
          <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 10, padding: '10px 12px' }}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 4 }}>En mora</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 14, fontWeight: 700, color: inMora > 0 ? '#ff3d3d' : '#555' }}>{inMora} créditos</div>
          </div>
        </div>
        {/* Search Bar */}
        <div style={{ position: 'relative', marginBottom: 14 }}>
          <span style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: '#444', display: 'flex' }}><IconSearch /></span>
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Buscar cliente por nombre o documento…"
            style={{ width: '100%', background: '#111', border: '1px solid #222', borderRadius: 10, padding: '10px 12px 10px 36px', color: '#f0f0f0', fontSize: 14 }}
          />
        </div>
        <div style={{ height: 1, background: '#1e1e1e' }} />
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px 16px' }}>
        {filteredActive.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#333', fontFamily: 'JetBrains Mono, monospace', fontSize: 13, paddingTop: 40 }}>Sin resultados</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {filteredActive.map(c => {
              const st = creditStatus(c)
              const pct = progressPct(c)
              const next = nextDueInstallment(c)
              const od = overdueCount(c)
              return (
                <div key={c.id} onClick={() => setSelectedId(c.id)} style={{ background: '#111', border: `1px solid ${st === 'mora' ? 'rgba(255,61,61,0.25)' : '#1e1e1e'}`, borderRadius: 12, padding: '14px 14px', cursor: 'pointer' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 10 }}>
                    <div style={{ flex: 1, paddingRight: 10 }}>
                      <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 2 }}>{c.clientName}</div>
                      <div style={{ fontSize: 12, color: '#555', marginBottom: 2 }}>{c.products}</div>
                      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#444', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                        <span>Tel: {c.clientPhone}</span>
                        {c.clientDocument && <span style={{ color: '#666' }}>· CC: {c.clientDocument}</span>}
                      </div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 15, fontWeight: 700, color: '#ff3d3d', marginBottom: 4 }}>{fmt(pendingBalance(c))}</div>
                      <StatusBadge status={st} />
                    </div>
                  </div>
                  <ProgressBar pct={pct} color={st === 'mora' ? '#ff9800' : st === 'finalizado' ? '#448aff' : '#00e676'} />
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
                    <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555' }}>{pct.toFixed(1)}% pagado</span>
                    {od > 0 && <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#ff3d3d', fontWeight: 600 }}>{od} cuota{od !== 1 ? 's' : ''} vencida{od !== 1 ? 's' : ''}</span>}
                    {od === 0 && next && st !== 'finalizado' && <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555' }}>Próximo: {fmtShortDate(next.dueDate)}</span>}
                    {st === 'finalizado' && <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#448aff' }}>Finalizado</span>}
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {showNewForm && <NewCreditModal onSave={c => { onAdd(c); setShowNewForm(false); setSelectedId(c.id) }} onClose={() => setShowNewForm(false)} />}
      {showFinalized && (
        <FinalizedCreditsModal
          credits={credits}
          onSelectCredit={setSelectedId}
          onClose={() => setShowFinalized(false)}
        />
      )}
    </div>
  )
}

function FinalizedCreditsModal({ credits, onSelectCredit, onClose }: { credits: Credit[]; onSelectCredit: (id: string) => void; onClose: () => void }) {
  const [search, setSearch] = useState('')

  const finalized = useMemo(() => credits.filter(c => creditStatus(c) === 'finalizado'), [credits])

  const filtered = useMemo(() => {
    return finalized.filter(c => {
      const s = search.toLowerCase()
      const nameMatch = c.clientName.toLowerCase().includes(s)
      const docMatch = c.clientDocument ? c.clientDocument.toLowerCase().includes(s) : false
      return nameMatch || docMatch
    })
  }, [finalized, search])

  return (
    <div className="fade-in" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 50, display: 'flex', alignItems: 'flex-end' }}>
      <div className="slide-up" style={{ background: '#0e0e0e', border: '1px solid #222', borderRadius: '20px 20px 0 0', width: '100%', maxHeight: '94vh', overflowY: 'auto', padding: '20px 16px 40px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20, flexShrink: 0 }}>
          <div>
            <div style={{ fontSize: 17, fontWeight: 600 }}>Créditos Finalizados</div>
            <div style={{ fontSize: 12, color: '#555', marginTop: 2 }}>{finalized.length} créditos completados</div>
          </div>
          <button onClick={onClose} style={{ background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 8, padding: 8, cursor: 'pointer', display: 'flex' }}><IconX /></button>
        </div>

        {/* Search Bar */}
        <div style={{ position: 'relative', marginBottom: 14, flexShrink: 0 }}>
          <span style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: '#444', display: 'flex' }}><IconSearch /></span>
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Buscar cliente por nombre o documento…"
            style={{ width: '100%', background: '#111', border: '1px solid #222', borderRadius: 10, padding: '10px 12px 10px 36px', color: '#f0f0f0', fontSize: 14 }}
          />
        </div>

        {/* List */}
        <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {filtered.length === 0 ? (
            <div style={{ textAlign: 'center', color: '#333', fontFamily: 'JetBrains Mono, monospace', fontSize: 13, paddingTop: 40 }}>
              Sin resultados
            </div>
          ) : (
            filtered.map(c => {
              const pct = progressPct(c)
              return (
                <div
                  key={c.id}
                  onClick={() => {
                    onSelectCredit(c.id)
                    onClose()
                  }}
                  style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '14px', cursor: 'pointer' }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 10 }}>
                    <div style={{ flex: 1, paddingRight: 10 }}>
                      <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 2 }}>{c.clientName}</div>
                      <div style={{ fontSize: 12, color: '#555', marginBottom: 2 }}>{c.products}</div>
                      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#444', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                        <span>Tel: {c.clientPhone}</span>
                        {c.clientDocument && <span style={{ color: '#666' }}>· CC: {c.clientDocument}</span>}
                      </div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 15, fontWeight: 700, color: '#00e676', marginBottom: 4 }}>{fmt(c.totalSale)}</div>
                      <StatusBadge status="finalizado" />
                    </div>
                  </div>
                  <ProgressBar pct={pct} color="#448aff" />
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
                    <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555' }}>100% Pagado</span>
                    <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#448aff' }}>Finalizado</span>
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}

// ─── Credit Detail ────────────────────────────────────────────────────────────

function CreditDetail({ credit, onBack, onUpdate }: { credit: Credit; onBack: () => void; onUpdate: (c: Credit) => void }) {
  const [showPayment, setShowPayment] = useState(false)
  const st = creditStatus(credit)
  const pct = progressPct(credit)
  const paid = totalPaid(credit)
  const pending = pendingBalance(credit)
  const next = nextDueInstallment(credit)
  const od = overdueCount(credit)

  // Running balance for table display
  let runningBal = credit.totalSale
  const rows = credit.installments.map(inst => {
    runningBal -= inst.paidAmount
    return { inst, balance: Math.max(0, runningBal) }
  })

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Header */}
      <div style={{ padding: '12px 16px 0', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <button onClick={onBack} style={{ background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 8, padding: 8, cursor: 'pointer', display: 'flex' }}><IconBack /></button>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase' }}>Crédito</div>
            <div style={{ fontSize: 16, fontWeight: 600 }}>{credit.clientName}</div>
          </div>
          <StatusBadge status={st} />
        </div>
        <div style={{ height: 1, background: '#1e1e1e' }} />
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 24px' }}>
        {/* Brand header like cartilla */}
        <div style={{ background: '#0d1a33', borderRadius: 12, padding: '14px 16px', marginBottom: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, background: '#fff', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <img src={logoImg} alt="Logo" style={{ width: 36, height: 36, objectFit: 'contain' }} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, fontWeight: 700, color: '#fff', letterSpacing: '0.04em' }}>ALFA GAMA STORE</div>
            <div style={{ fontSize: 11, color: '#4a7abf', fontStyle: 'italic' }}>Moda, Calidad y Estilo</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#4a7abf', letterSpacing: '0.08em', textTransform: 'uppercase' }}>Registro</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, fontWeight: 600, color: '#fff' }}>{fmtDate(credit.startDate)}</div>
          </div>
        </div>

        {/* Client info */}
        <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '14px', marginBottom: 10 }}>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#448aff', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Datos del cliente</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', marginBottom: 2 }}>NOMBRE</div>
              <div style={{ fontSize: 14, fontWeight: 500 }}>{credit.clientName}</div>
            </div>
            <div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', marginBottom: 2 }}>DOCUMENTO</div>
              <div style={{ fontSize: 14, fontWeight: 500 }}>{credit.clientDocument || '—'}</div>
            </div>
            <div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', marginBottom: 2 }}>TELÉFONO</div>
              <div style={{ fontSize: 14, fontWeight: 500 }}>{credit.clientPhone}</div>
            </div>
            {credit.clientAddress && (
              <div>
                <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', marginBottom: 2 }}>DIRECCIÓN</div>
                <div style={{ fontSize: 13, color: '#c0c0c0' }}>{credit.clientAddress}</div>
              </div>
            )}
            <div style={{ gridColumn: '1/-1' }}>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', marginBottom: 2 }}>PRODUCTO(S)</div>
              <div style={{ fontSize: 13, color: '#c0c0c0' }}>{credit.products}</div>
            </div>
          </div>
        </div>

        {/* Account summary */}
        <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '14px', marginBottom: 10 }}>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#448aff', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 12 }}>Resumen de la cuenta</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 14 }}>
            <div style={{ background: '#141414', borderRadius: 8, padding: '10px' }}>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#555', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 4 }}>Total venta</div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, fontWeight: 700, color: '#f0f0f0' }}>{fmt(credit.totalSale)}</div>
            </div>
            <div style={{ background: 'rgba(0,230,118,0.08)', border: '1px solid rgba(0,230,118,0.15)', borderRadius: 8, padding: '10px' }}>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#00a854', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 4 }}>Abonado</div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, fontWeight: 700, color: '#00e676' }}>{fmt(paid)}</div>
            </div>
            <div style={{ background: 'rgba(255,61,61,0.08)', border: '1px solid rgba(255,61,61,0.2)', borderRadius: 8, padding: '10px' }}>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#cc3333', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 4 }}>Saldo</div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, fontWeight: 700, color: '#ff3d3d' }}>{fmt(pending)}</div>
            </div>
          </div>
          {/* Progress */}
          <div style={{ marginBottom: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555' }}>Avance del pago</span>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, fontWeight: 700, color: st === 'mora' ? '#ff9800' : '#00e676' }}>{pct.toFixed(1)}%</span>
            </div>
            <ProgressBar pct={pct} color={st === 'mora' ? '#ff9800' : st === 'finalizado' ? '#448aff' : '#00e676'} height={8} />
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#444', marginTop: 4 }}>
              ({fmt(paid)} de {fmt(credit.totalSale)})
            </div>
          </div>
        </div>

        {/* Credit terms */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 10 }}>
          {[
            { label: 'Valor cuota', value: fmt(credit.quotaValue), color: '#f0f0f0' },
            { label: 'Frecuencia', value: FREQ_LABELS[credit.paymentFrequency], color: '#f0f0f0' },
            { label: 'Total cuotas', value: `${credit.totalQuotas}`, color: '#448aff' },
          ].map(({ label, value, color }) => (
            <div key={label} style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 10, padding: '10px 10px' }}>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#555', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 4 }}>{label}</div>
              <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, fontWeight: 700, color }}>{value}</div>
            </div>
          ))}
        </div>

        {/* Alerts */}
        {od > 0 && (
          <div style={{ background: 'rgba(255,61,61,0.08)', border: '1px solid rgba(255,61,61,0.2)', borderRadius: 10, padding: '12px 14px', marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
            <IconAlert />
            <span style={{ fontSize: 13, color: '#ff3d3d', fontWeight: 500 }}>{od} cuota{od !== 1 ? 's' : ''} vencida{od !== 1 ? 's' : ''} sin pago</span>
          </div>
        )}
        {next && st !== 'finalizado' && od === 0 && (
          <div style={{ background: 'rgba(68,138,255,0.08)', border: '1px solid rgba(68,138,255,0.2)', borderRadius: 10, padding: '10px 14px', marginBottom: 10 }}>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#448aff' }}>Próximo pago: {fmtDate(next.dueDate)} · {fmt(next.quotaValue)}</span>
          </div>
        )}

        {/* Register payment button */}
        {st !== 'finalizado' && (
          <button onClick={() => setShowPayment(true)} style={{ width: '100%', background: '#448aff', color: '#fff', border: 'none', borderRadius: 12, padding: '13px', fontSize: 14, fontWeight: 700, cursor: 'pointer', marginBottom: 16, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            <IconCheck /> Registrar pago
          </button>
        )}

        {/* Payment plan table */}
        <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, overflow: 'hidden', marginBottom: 14 }}>
          <div style={{ padding: '12px 14px', borderBottom: '1px solid #1e1e1e', background: '#0d1a33' }}>
            <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#4a9eff' }}>Plan de pagos</span>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 580 }}>
              <thead>
                <tr style={{ background: '#0a0a0a' }}>
                  {['N°', 'Fecha', 'Cuota', 'Abono', 'Saldo', 'Estado', 'Obs.'].map(h => (
                    <th key={h} style={{ padding: '8px 10px', fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.07em', textAlign: 'left', borderBottom: '1px solid #1e1e1e', whiteSpace: 'nowrap' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map(({ inst, balance }, idx) => {
                  const s = instStatus(inst)
                  const isEven = idx % 2 === 0
                  return (
                    <tr key={inst.quotaNumber} style={{ background: isEven ? '#0e0e0e' : '#111' }}>
                      <td style={{ padding: '9px 10px', fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#555', borderBottom: '1px solid #151515' }}>{inst.quotaNumber}</td>
                      <td style={{ padding: '9px 10px', fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: s === 'vencido' ? '#ff3d3d' : '#888', borderBottom: '1px solid #151515', whiteSpace: 'nowrap' }}>{fmtDate(inst.dueDate)}</td>
                      <td style={{ padding: '9px 10px', fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#888', borderBottom: '1px solid #151515', whiteSpace: 'nowrap' }}>{fmt(inst.quotaValue)}</td>
                      <td style={{ padding: '9px 10px', fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: inst.paidAmount > 0 ? '#00e676' : '#333', borderBottom: '1px solid #151515', whiteSpace: 'nowrap' }}>
                        {inst.paidAmount > 0 ? fmt(inst.paidAmount) : '—'}
                      </td>
                      <td style={{ padding: '9px 10px', fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: balance > 0 ? '#ff3d3d' : '#00e676', borderBottom: '1px solid #151515', whiteSpace: 'nowrap' }}>{fmt(balance)}</td>
                      <td style={{ padding: '9px 10px', borderBottom: '1px solid #151515' }}><InstStatusBadge status={s} /></td>
                      <td style={{ padding: '9px 10px', fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#444', borderBottom: '1px solid #151515', whiteSpace: 'nowrap' }}>{inst.paymentMethod || '—'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Notes */}
        {credit.generalNotes && (
          <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '14px' }}>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 8 }}>Observaciones generales</div>
            <div style={{ fontSize: 13, color: '#888', lineHeight: 1.5 }}>{credit.generalNotes}</div>
          </div>
        )}

        {/* Footer */}
        <div style={{ textAlign: 'center', marginTop: 20, fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#2a2a2a', fontStyle: 'italic' }}>
          "Tu estilo, nuestra pasión"
        </div>
      </div>

      {showPayment && (
        <RegisterPaymentModal
          credit={credit}
          onSave={updatedCredit => { onUpdate(updatedCredit); setShowPayment(false) }}
          onClose={() => setShowPayment(false)}
        />
      )}
    </div>
  )
}

// ─── Register Payment Modal ───────────────────────────────────────────────────

function RegisterPaymentModal({ credit, onSave, onClose }: { credit: Credit; onSave: (c: Credit) => void; onClose: () => void }) {
  const pendingInsts = credit.installments.filter(i => instStatus(i) !== 'pagado')
  const [selectedIdx, setSelectedIdx] = useState(credit.installments.findIndex(i => instStatus(i) !== 'pagado'))
  const [amount, setAmount] = useState(selectedIdx >= 0 ? credit.installments[selectedIdx].quotaValue.toString() : '')
  const [method, setMethod] = useState<'efectivo' | 'tarjeta' | 'transferencia'>('efectivo')
  const [notes, setNotes] = useState('')
  const pmColor = (m: string) => m === 'efectivo' ? '#00e676' : m === 'tarjeta' ? '#448aff' : '#ff9800'

  if (pendingInsts.length === 0) {
    return (
      <div className="fade-in" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', zIndex: 60, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
        <div style={{ background: '#0e0e0e', border: '1px solid #222', borderRadius: 16, padding: 24, textAlign: 'center' }}>
          <div style={{ fontSize: 32, marginBottom: 8 }}>✓</div>
          <div style={{ fontSize: 15, fontWeight: 600, color: '#00e676' }}>Crédito finalizado</div>
          <button onClick={onClose} style={{ marginTop: 16, background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 8, padding: '8px 20px', cursor: 'pointer' }}>Cerrar</button>
        </div>
      </div>
    )
  }

  const handleSave = () => {
    if (selectedIdx < 0 || !Number(amount)) return
    const updated = { ...credit, installments: credit.installments.map((inst, i) => {
      if (i !== selectedIdx) return inst
      return { ...inst, paidAmount: inst.paidAmount + Number(amount), paidDate: new Date(), paymentMethod: method, notes }
    })}
    onSave(updated)
  }

  return (
    <div className="fade-in" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 60, display: 'flex', alignItems: 'flex-end' }}>
      <div className="slide-up" style={{ background: '#0e0e0e', border: '1px solid #222', borderRadius: '20px 20px 0 0', width: '100%', maxHeight: '90vh', overflowY: 'auto', padding: '20px 16px 40px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <div>
            <div style={{ fontSize: 17, fontWeight: 600 }}>Registrar pago</div>
            <div style={{ fontSize: 12, color: '#555', marginTop: 2 }}>{credit.clientName}</div>
          </div>
          <button onClick={onClose} style={{ background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 8, padding: 8, cursor: 'pointer', display: 'flex' }}><IconX /></button>
        </div>

        {/* Select installment */}
        <div style={{ marginBottom: 16 }}>
          <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Cuota a pagar</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {credit.installments.map((inst, i) => {
              const s = instStatus(inst)
              if (s === 'pagado') return null
              return (
                <button key={i} onClick={() => { setSelectedIdx(i); setAmount(inst.quotaValue.toString()) }} style={{ background: selectedIdx === i ? 'rgba(68,138,255,0.12)' : '#141414', border: `1px solid ${selectedIdx === i ? '#448aff' : '#222'}`, borderRadius: 10, padding: '12px 14px', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: '#f0f0f0', textAlign: 'left' }}>
                  <div>
                    <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, fontWeight: 600 }}>Cuota {inst.quotaNumber}</div>
                    <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: s === 'vencido' ? '#ff3d3d' : '#555', marginTop: 2 }}>{fmtDate(inst.dueDate)}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, fontWeight: 600, color: s === 'vencido' ? '#ff3d3d' : '#f0f0f0' }}>{fmt(inst.quotaValue)}</div>
                    <InstStatusBadge status={s} />
                  </div>
                </button>
              )
            })}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <Field label="Valor del abono">
            <input value={amount} onChange={e => setAmount(e.target.value)} type="number" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace', fontSize: 16 }} />
          </Field>
          <div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Método de pago</div>
            <div style={{ display: 'flex', gap: 8 }}>
              {PAYMENT_METHODS.map(m => (
                <button key={m} onClick={() => setMethod(m)} style={{ flex: 1, background: method === m ? `${pmColor(m)}18` : '#141414', color: method === m ? pmColor(m) : '#666', border: `1px solid ${method === m ? pmColor(m) : '#222'}`, borderRadius: 10, padding: '9px 0', fontSize: 12, fontWeight: 600, cursor: 'pointer', textTransform: 'capitalize' }}>{m}</button>
              ))}
            </div>
          </div>
          <Field label="Observaciones">
            <input value={notes} onChange={e => setNotes(e.target.value)} placeholder="Referencia, observación…" style={{ ...inputStyle, background: '#141414' }} />
          </Field>
        </div>

        {/* Summary */}
        {selectedIdx >= 0 && Number(amount) > 0 && (
          <div style={{ background: 'rgba(68,138,255,0.08)', border: '1px solid rgba(68,138,255,0.2)', borderRadius: 10, padding: '12px 14px', margin: '16px 0 0' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 11, color: '#555' }}>Nuevo saldo pendiente</span>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 14, fontWeight: 700, color: '#448aff' }}>{fmt(Math.max(0, pendingBalance(credit) - Number(amount)))}</span>
            </div>
          </div>
        )}

        <button onClick={handleSave} disabled={selectedIdx < 0 || !Number(amount)} style={{ width: '100%', background: selectedIdx >= 0 && Number(amount) > 0 ? '#448aff' : '#1a1a1a', color: selectedIdx >= 0 && Number(amount) > 0 ? '#fff' : '#444', border: 'none', borderRadius: 12, padding: 15, fontSize: 15, fontWeight: 700, cursor: selectedIdx >= 0 && Number(amount) > 0 ? 'pointer' : 'not-allowed', marginTop: 14 }}>
          Confirmar pago · {fmt(Number(amount) || 0)}
        </button>
      </div>
    </div>
  )
}

// ─── New Credit Modal ─────────────────────────────────────────────────────────

function NewCreditModal({ onSave, onClose }: { onSave: (c: Credit) => void; onClose: () => void }) {
  const [clientName, setClientName] = useState('')
  const [clientPhone, setClientPhone] = useState('')
  const [clientAddress, setClientAddress] = useState('')
  const [clientDocument, setClientDocument] = useState('')
  const [products, setProducts] = useState('')
  const [totalSale, setTotalSale] = useState('')
  const [frequency, setFrequency] = useState<'semanal' | 'quincenal' | 'mensual'>('mensual')
  const [totalQuotas, setTotalQuotas] = useState('')
  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10))

  const quotaValue = totalQuotas && totalSale ? Math.ceil(Number(totalSale) / Number(totalQuotas)) : 0
  const valid = clientName.trim() && products.trim() && Number(totalSale) > 0 && Number(totalQuotas) > 0

  const handleSave = () => {
    if (!valid) return
    const sd = new Date(startDate + 'T00:00:00')
    const credit: Credit = {
      id: uid(), clientName: clientName.trim(), clientPhone: clientPhone.trim(), clientAddress: clientAddress.trim(),
      clientDocument: clientDocument.trim(),
      products: products.trim(), totalSale: Number(totalSale), startDate: sd, paymentFrequency: frequency,
      totalQuotas: Number(totalQuotas), quotaValue,
      installments: generateInstallments(sd, frequency, Number(totalQuotas), quotaValue),
      generalNotes: '',
    }
    onSave(credit)
  }

  return (
    <div className="fade-in" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 50, display: 'flex', alignItems: 'flex-end' }}>
      <div className="slide-up" style={{ background: '#0e0e0e', border: '1px solid #222', borderRadius: '20px 20px 0 0', width: '100%', maxHeight: '94vh', overflowY: 'auto', padding: '20px 16px 40px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <div style={{ fontSize: 17, fontWeight: 600 }}>Nuevo crédito</div>
          <button onClick={onClose} style={{ background: '#1a1a1a', border: 'none', color: '#888', borderRadius: 8, padding: 8, cursor: 'pointer', display: 'flex' }}><IconX /></button>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <Field label="Nombre del cliente"><input value={clientName} onChange={e => setClientName(e.target.value)} placeholder="Luchy Tolu" style={inputStyle} /></Field>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="Documento de identidad"><input value={clientDocument} onChange={e => setClientDocument(e.target.value)} placeholder="1098765432" style={inputStyle} /></Field>
            <Field label="Teléfono"><input value={clientPhone} onChange={e => setClientPhone(e.target.value)} placeholder="300 123 4567" style={inputStyle} /></Field>
          </div>
          <Field label="Dirección"><input value={clientAddress} onChange={e => setClientAddress(e.target.value)} placeholder="Cra 5 #12-34" style={inputStyle} /></Field>
          <Field label="Producto(s)"><input value={products} onChange={e => setProducts(e.target.value)} placeholder="Televisor, Colchón base cama…" style={inputStyle} /></Field>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="Total venta">
              <input value={totalSale} onChange={e => setTotalSale(e.target.value)} type="number" placeholder="3200000" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace' }} />
            </Field>
            <Field label="N° cuotas">
              <input value={totalQuotas} onChange={e => setTotalQuotas(e.target.value)} type="number" placeholder="12" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace' }} />
            </Field>
          </div>
          <div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#555', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Frecuencia de pago</div>
            <div style={{ display: 'flex', gap: 8 }}>
              {(['semanal', 'quincenal', 'mensual'] as const).map(f => (
                <button key={f} onClick={() => setFrequency(f)} style={{ flex: 1, background: frequency === f ? 'rgba(68,138,255,0.12)' : '#141414', color: frequency === f ? '#448aff' : '#666', border: `1px solid ${frequency === f ? '#448aff' : '#222'}`, borderRadius: 10, padding: '9px 0', fontSize: 12, fontWeight: 600, cursor: 'pointer', textTransform: 'capitalize' }}>{FREQ_LABELS[f]}</button>
              ))}
            </div>
          </div>
          <Field label="Fecha de registro"><input value={startDate} onChange={e => setStartDate(e.target.value)} type="date" style={{ ...inputStyle, fontFamily: 'JetBrains Mono, monospace', colorScheme: 'dark' }} /></Field>

          {quotaValue > 0 && (
            <div style={{ background: 'rgba(68,138,255,0.08)', border: '1px solid rgba(68,138,255,0.2)', borderRadius: 10, padding: '12px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, color: '#555' }}>Valor por cuota</span>
              <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 16, fontWeight: 700, color: '#448aff' }}>{fmt(quotaValue)}</span>
            </div>
          )}

          <button onClick={handleSave} disabled={!valid} style={{ background: valid ? '#448aff' : '#1a1a1a', color: valid ? '#fff' : '#444', border: 'none', borderRadius: 12, padding: 14, fontSize: 15, fontWeight: 700, cursor: valid ? 'pointer' : 'not-allowed', marginTop: 4 }}>
            Crear crédito
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Main App ─────────────────────────────────────────────────────────────────

type Tab = 'dashboard' | 'inventory' | 'credit' | 'sales'

export default function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [products, setProducts] = useState<Product[]>(SEED_PRODUCTS)
  const [sales, setSales] = useState<Sale[]>(SEED_SALES)
  const [credits, setCredits] = useState<Credit[]>(SEED_CREDITS)
  const [tab, setTab] = useState<Tab>('dashboard')
  const [showNewSale, setShowNewSale] = useState(false)

  if (!isLoggedIn) return <LoginScreen onLogin={() => setIsLoggedIn(true)} />

  const handleAddProduct = (p: Product) => setProducts(prev => [...prev, p])
  const handleUpdateProduct = (p: Product) => setProducts(prev => prev.map(x => x.id === p.id ? p : x))
  const handleDeleteProduct = (id: string) => setProducts(prev => prev.filter(x => x.id !== id))
  const handleAddSale = (sale: Sale) => {
    setSales(prev => [...prev, sale])
    setProducts(prev => prev.map(p => { const l = sale.lines.find(l => l.productId === p.id); return l ? { ...p, stock: Math.max(0, p.stock - l.qty) } : p }))
    setShowNewSale(false)
  }
  const handleAddCredit = (c: Credit) => setCredits(prev => [...prev, c])
  const handleUpdateCredit = (c: Credit) => setCredits(prev => prev.map(x => x.id === c.id ? c : x))

  const lowStockCount = products.filter(p => p.stock <= p.minStock).length
  const creditMoraCount = credits.filter(c => creditStatus(c) === 'mora').length

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100dvh', maxWidth: 430, margin: '0 auto', background: '#080808', position: 'relative' }}>
      {/* App header */}
      <div style={{ flexShrink: 0, background: '#0a0a0a', borderBottom: '1px solid #161616', padding: '10px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, background: '#fff', borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <img src={logoImg} alt="Logo" style={{ width: 26, height: 26, objectFit: 'contain' }} />
          </div>
          <div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 12, fontWeight: 700, color: '#f0f0f0', letterSpacing: '0.04em' }}>ALFA GAMA STORE</div>
            <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 9, color: '#444', letterSpacing: '0.06em' }}>MODA · CALIDAD · ESTILO</div>
          </div>
        </div>
        <button onClick={() => setIsLoggedIn(false)} style={{ background: '#1a1a1a', border: 'none', color: '#555', borderRadius: 8, padding: 7, cursor: 'pointer', display: 'flex' }}>
          <IconLogout />
        </button>
      </div>

      {/* Content */}
      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        {tab === 'dashboard' && <DashboardTab products={products} sales={sales} credits={credits} />}
        {tab === 'inventory' && <InventoryTab products={products} onAdd={handleAddProduct} onUpdate={handleUpdateProduct} onDelete={handleDeleteProduct} />}
        {tab === 'credit' && <CreditTab credits={credits} onAdd={handleAddCredit} onUpdate={handleUpdateCredit} />}
        {tab === 'sales' && <SalesTab sales={sales} />}
      </div>

      {/* Bottom Nav — 5 items with Vender in center */}
      <div style={{ flexShrink: 0, background: '#0a0a0a', borderTop: '1px solid #161616', display: 'flex', alignItems: 'stretch', paddingBottom: 'env(safe-area-inset-bottom, 0)' }}>
        {/* Inicio */}
        <NavBtn label="Inicio" active={tab === 'dashboard'} onClick={() => setTab('dashboard')}><IconGrid /></NavBtn>
        {/* Inventario */}
        <NavBtn label="Inventario" active={tab === 'inventory'} onClick={() => setTab('inventory')} badge={lowStockCount > 0 ? lowStockCount : undefined}><IconBox /></NavBtn>

        {/* CENTER: Vender FAB */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '8px 0 10px' }}>
          <button
            onClick={() => setShowNewSale(true)}
            style={{ background: '#00e676', borderRadius: 16, width: 46, height: 46, display: 'flex', alignItems: 'center', justifyContent: 'center', border: 'none', cursor: 'pointer', boxShadow: '0 0 20px rgba(0,230,118,0.3)', transition: 'transform 0.15s' }}
          >
            <IconPlus size={22} />
          </button>
          <span style={{ fontSize: 10, fontWeight: 600, color: '#00e676', marginTop: 4, letterSpacing: '0.02em' }}>Vender</span>
        </div>

        {/* Crédito */}
        <NavBtn label="Crédito" active={tab === 'credit'} onClick={() => setTab('credit')} badge={creditMoraCount > 0 ? creditMoraCount : undefined} badgeColor="#ff3d3d"><IconCreditCard /></NavBtn>
        {/* Ventas */}
        <NavBtn label="Ventas" active={tab === 'sales'} onClick={() => setTab('sales')}><IconReceipt /></NavBtn>
      </div>

      {showNewSale && <NewSaleModal products={products} onSave={handleAddSale} onClose={() => setShowNewSale(false)} />}
    </div>
  )
}

function NavBtn({ label, active, onClick, children, badge, badgeColor = '#ff9800' }: { label: string; active: boolean; onClick: () => void; children: React.ReactNode; badge?: number; badgeColor?: string }) {
  return (
    <button onClick={onClick} style={{ flex: 1, background: 'transparent', border: 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, padding: '10px 0 12px', cursor: 'pointer', color: active ? '#00e676' : '#444', transition: 'color 0.15s', position: 'relative' }}>
      {badge !== undefined && (
        <span style={{ position: 'absolute', top: 8, right: 'calc(50% - 18px)', background: badgeColor, color: '#fff', fontSize: 10, fontWeight: 700, minWidth: 16, height: 16, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'JetBrains Mono, monospace' }}>{badge}</span>
      )}
      {children}
      <span style={{ fontSize: 10, fontWeight: active ? 600 : 400, letterSpacing: '0.02em' }}>{label}</span>
    </button>
  )
}
