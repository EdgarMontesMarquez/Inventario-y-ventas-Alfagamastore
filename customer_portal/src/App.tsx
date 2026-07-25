import { useState, useEffect } from 'react';
import { supabase } from './lib/supabase';
import type { Credit, Customer } from './types';
import { 
  Search, 
  CreditCard, 
  CheckCircle2, 
  AlertTriangle, 
  Eye, 
  X, 
  Phone, 
  MapPin, 
  MessageSquare,
  ShieldCheck,
  Clock,
  Sparkles,
  ExternalLink,
  UserCheck
} from 'lucide-react';

export function App() {
  const [docType, setDocType] = useState<string>('CC');
  const [docId, setDocId] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [searched, setSearched] = useState<boolean>(false);
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [credits, setCredits] = useState<Credit[]>([]);
  const [selectedImage, setSelectedImage] = useState<{ url: string; title: string } | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Auto-cargar si se pasa por parámetro de la URL (ej: ?doc_type=CC&doc_id=1107858381)
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const typeParam = params.get('doc_type') || params.get('tipo');
    const idParam = params.get('doc_id') || params.get('cedula') || params.get('id');

    if (typeParam) setDocType(typeParam.toUpperCase());
    if (idParam) {
      setDocId(idParam);
      handleSearch(typeParam || 'CC', idParam);
    }
  }, []);

  const handleSearch = async (typeToUse = docType, idToUse = docId) => {
    const rawSearch = idToUse.trim();
    const cleanId = rawSearch.replace(/[^a-zA-Z0-9]/g, '');

    if (!cleanId) {
      setErrorMsg('Por favor ingresa un número de documento válido.');
      return;
    }

    setLoading(true);
    setErrorMsg(null);
    setSearched(true);
    setCustomer(null);
    setCredits([]);

    try {
      // 1. Consulta simple de clientes en public.customers
      let foundCustomer: Customer | null = null;
      try {
        const { data: allCustomers, error: custError } = await supabase
          .from('customers')
          .select('*');

        if (custError) {
          console.warn('Advertencia en customers:', custError.message);
        }

        if (allCustomers && allCustomers.length > 0) {
          const match = allCustomers.find((c: any) => {
            const doc = String(c.document_id || '').replace(/[^a-zA-Z0-9]/g, '');
            const phone = String(c.phone || '').replace(/[^a-zA-Z0-9]/g, '');
            const name = String(c.name || '').toLowerCase();
            return (
              doc === cleanId || 
              doc.includes(cleanId) || 
              cleanId.includes(doc) || 
              phone === cleanId || 
              phone.includes(cleanId) || 
              (cleanId.length >= 3 && name.includes(cleanId.toLowerCase()))
            );
          });

          if (match) {
            foundCustomer = {
              id: String(match.id),
              name: match.name || 'Cliente AlfaGama',
              phone: match.phone || '',
              address: match.address || '',
              document_type: match.document_type || typeToUse,
              document_id: match.document_id || cleanId
            };
            setCustomer(foundCustomer);
          }
        }
      } catch (e) {
        console.warn('Excepción consulta customers:', e);
      }

      // 2. Consulta simple de créditos en public.credits
      const { data: allCredits, error: credErr } = await supabase
        .from('credits')
        .select('*');

      if (credErr) {
        console.error('Error cargando créditos de Supabase:', credErr);
        setErrorMsg(`Error de conexión con la base de datos: ${credErr.message}`);
        setLoading(false);
        return;
      }

      let rawCredits: Record<string, any>[] = [];

      if (allCredits && allCredits.length > 0) {
        rawCredits = allCredits.filter((c: any) => {
          const notesStr = String(c.notes || '');
          const cleanNotes = notesStr.replace(/[^a-zA-Z0-9]/g, '');
          const custIdStr = String(c.customer_id || '');
          const phoneStr = String(c.customer_phone || '').replace(/[^a-zA-Z0-9]/g, '');
          const nameStr = String(c.customer_name || '').toLowerCase();

          const matchByCustId = foundCustomer ? custIdStr === foundCustomer.id : false;
          const matchByNotes = notesStr.includes(rawSearch) || cleanNotes.includes(cleanId) || notesStr.includes(cleanId);
          const matchByPhone = phoneStr.includes(cleanId);
          const matchByName = foundCustomer ? nameStr.includes(foundCustomer.name.toLowerCase()) : false;

          return matchByCustId || matchByNotes || matchByPhone || matchByName;
        });
      }

      if (rawCredits.length === 0) {
        setLoading(false);
        return;
      }

      // 3. Cargar Cuotas (Installments) de forma segura para cada crédito
      const fullCredits: Credit[] = await Promise.all(
        rawCredits.map(async (c: any) => {
          let instList: any[] = [];
          try {
            const { data: instData } = await supabase
              .from('credit_installments')
              .select('*')
              .eq('credit_id', c.id)
              .order('number', { ascending: true });
            if (instData) instList = instData;
          } catch (_) {}

          const totalAmt = Number(c.total_amount || 0);
          const paidAmt = Number(c.paid_amount || 0);

          return {
            id: String(c.id),
            customer_id: c.customer_id ? String(c.customer_id) : undefined,
            customer_name: c.customer_name || foundCustomer?.name || 'Cliente AlfaGama',
            customer_phone: c.customer_phone || foundCustomer?.phone || '',
            customer_address: c.customer_address || foundCustomer?.address || '',
            products: c.products || 'Productos adquiridos a crédito',
            total_amount: totalAmt,
            paid_amount: paidAmt,
            interest_rate: Number(c.interest_rate || 0),
            interest_amount: Number(c.interest_amount || 0),
            installments_count: Number(c.installments_count || (instList.length > 0 ? instList.length : 1)),
            payment_frequency: c.payment_frequency || 'mensual',
            status: c.status || (paidAmt >= totalAmt ? 'finalizado' : 'activo'),
            due_date: c.due_date || new Date().toISOString(),
            notes: c.notes,
            created_at: c.created_at || new Date().toISOString(),
            installments: instList.map((inst: any) => ({
              id: String(inst.id),
              credit_id: String(inst.credit_id),
              number: Number(inst.number || 1),
              amount: Number(inst.amount || 0),
              paid_amount: Number(inst.paid_amount || 0),
              due_date: inst.due_date,
              is_paid: Boolean(inst.is_paid),
              paid_at: inst.paid_at,
              payment_method: inst.payment_method,
              notes: inst.notes,
              receipt_image_url: inst.receipt_image_url
            }))
          };
        })
      );

      setCredits(fullCredits);
    } catch (err: any) {
      setErrorMsg(err.message || 'No se pudo consultar la base de datos de Supabase.');
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (val: number) => {
    return new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      maximumFractionDigits: 0
    }).format(val);
  };

  const formatDate = (dateStr?: string) => {
    if (!dateStr) return '-';
    try {
      const dt = new Date(dateStr);
      return dt.toLocaleDateString('es-CO', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      });
    } catch (_) {
      return dateStr;
    }
  };

  return (
    <div className="min-h-screen bg-[#F4F7FF] text-[#0A192F] flex flex-col justify-between font-['Inter',sans-serif]">
      {/* Header Bar - Azul Noche & Azul Eléctrico */}
      <header className="bg-[#0A192F] text-white border-b border-slate-800 sticky top-0 z-30 shadow-md">
        <div className="max-w-4xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img 
              src="/logo_compact.png" 
              alt="Alfa Gama Store Logo" 
              className="w-12 h-12 object-contain rounded-xl" 
            />
            <div>
              <h1 className="font-heading font-extrabold text-base sm:text-lg text-white leading-tight tracking-wide">
                ALFA GAMA STORE
              </h1>
              <p className="text-[10px] sm:text-[11px] text-[#0066FF] font-semibold tracking-wider uppercase">
                PORTAL DE CRÉDITOS Y ESTADO DE CUENTA
              </p>
            </div>
          </div>
          <div className="hidden sm:flex items-center gap-2 text-xs text-slate-300 bg-slate-800/80 border border-slate-700 px-3 py-1.5 rounded-full shadow-inner">
            <ShieldCheck className="w-4 h-4 text-[#10B981]" />
            <span className="font-medium">Consulta Segura 24/7</span>
          </div>
        </div>
      </header>

      {/* Main Content Container */}
      <main className="max-w-4xl mx-auto px-4 py-6 sm:py-8 w-full grow">
        {/* Card de Búsqueda Principal */}
        <div className="glass-card-alfa rounded-2xl p-5 sm:p-8 mb-8 border border-slate-200 shadow-xl relative overflow-hidden bg-white">
          {/* Accent Bar Top en Azul Eléctrico */}
          <div className="absolute top-0 left-0 right-0 h-1.5 bg-[#0066FF]" />

          <div className="text-center max-w-xl mx-auto mb-6 pt-1">
            <h2 className="font-heading font-extrabold text-2xl sm:text-3xl text-[#0A192F] mb-2 leading-tight">
              Consulta tu Historial de Crédito
            </h2>
            <p className="text-[#475569] text-xs sm:text-sm leading-relaxed">
              Ingresa tu tipo y número de documento registrado para consultar saldos, fechas de pago y fotos de comprobantes.
            </p>
          </div>

          {/* Formulario de Búsqueda Móvil y Desktop (Sin Submit HTML nativo para evitar recargas) */}
          <div 
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                handleSearch();
              }
            }}
            className="flex flex-col sm:flex-row gap-3 max-w-2xl mx-auto"
          >
            {/* Selector de Tipo de Documento */}
            <div className="w-full sm:w-48">
              <label className="block text-[11px] font-bold text-[#475569] uppercase tracking-wider mb-1">
                TIPO DOC.
              </label>
              <select
                value={docType}
                onChange={(e) => setDocType(e.target.value)}
                className="w-full bg-white border border-slate-300 rounded-xl px-3.5 py-3 text-sm font-semibold text-[#0A192F] focus:outline-none focus:ring-2 focus:ring-[#0066FF] focus:border-[#0066FF] shadow-xs cursor-pointer min-h-12"
              >
                <option value="CC">Cédula Ciudadanía (CC)</option>
                <option value="CE">Cédula Extranjería (CE)</option>
                <option value="NIT">NIT / RUT</option>
                <option value="PAS">Pasaporte</option>
              </select>
            </div>

            {/* Input Número de Documento */}
            <div className="flex-1">
              <label className="block text-[11px] font-bold text-[#475569] uppercase tracking-wider mb-1">
                NÚMERO DE DOCUMENTO
              </label>
              <div className="relative">
                <input
                  type="text"
                  inputMode="numeric"
                  placeholder="Ej: 1107858381"
                  value={docId}
                  onChange={(e) => setDocId(e.target.value)}
                  className="w-full bg-white border border-slate-300 rounded-xl pl-4 pr-10 py-3 text-sm font-semibold text-[#0A192F] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0066FF] focus:border-[#0066FF] shadow-xs min-h-12"
                />
                {docId && (
                  <button
                    type="button"
                    onClick={() => setDocId('')}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-1.5"
                  >
                    <X className="w-4 h-4" />
                  </button>
                )}
              </div>
            </div>

            {/* Botón Consultar táctil */}
            <div className="sm:self-end w-full sm:w-auto">
              <button
                type="button"
                onClick={() => handleSearch()}
                disabled={loading}
                className="w-full sm:w-auto bg-[#0066FF] hover:bg-[#0052CC] text-white font-bold px-6 py-3 rounded-xl transition-all duration-200 flex items-center justify-center gap-2 shadow-lg shadow-blue-200 active:scale-95 disabled:opacity-50 min-h-12 cursor-pointer"
              >
                {loading ? (
                  <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <>
                    <Search className="w-4 h-4" />
                    <span>Consultar</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {errorMsg && (
            <div className="mt-4 p-3.5 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-xl flex items-center gap-2 max-w-2xl mx-auto shadow-xs">
              <AlertTriangle className="w-4 h-4 shrink-0 text-red-600" />
              <span>{errorMsg}</span>
            </div>
          )}
        </div>

        {/* Resultados de la Consulta */}
        {searched && !loading && (
          credits.length === 0 ? (
            <div className="bg-white rounded-2xl p-8 sm:p-12 text-center border border-slate-200 shadow-sm">
              <div className="w-16 h-16 bg-[#F4F7FF] text-slate-400 rounded-full flex items-center justify-center mx-auto mb-4 border border-[#BFDBFE]">
                <CreditCard className="w-8 h-8 text-[#0066FF]" />
              </div>
              <h3 className="font-heading font-bold text-lg sm:text-xl text-[#0A192F] mb-1">Sin créditos registrados</h3>
              <p className="text-[#475569] text-xs sm:text-sm max-w-md mx-auto leading-relaxed">
                No se encontraron créditos asociados al número <strong className="text-[#0A192F]">{docType} {docId}</strong>. Verifica que esté bien escrito o comunícate con la tienda.
              </p>
              <div className="mt-6">
                <a
                  href="https://wa.me/573163142258"
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-2 bg-[#10B981] hover:bg-[#047857] text-white font-bold text-xs px-4 py-3 rounded-xl transition-colors shadow-md shadow-emerald-200"
                >
                  <MessageSquare className="w-4 h-4" />
                  <span>Soporte por WhatsApp</span>
                </a>
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              {/* Tarjeta Titular del Crédito */}
              <div className="bg-white rounded-2xl p-5 sm:p-6 border border-slate-200 shadow-sm flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-xl bg-[#E6F0FF] text-[#0066FF] flex items-center justify-center shrink-0 border border-[#BFDBFE]">
                    <UserCheck className="w-6 h-6" />
                  </div>
                  <div>
                    <span className="text-[10px] font-bold text-[#0066FF] uppercase tracking-wider block mb-0.5">TITULAR REGISTRADO</span>
                    <h3 className="font-heading font-extrabold text-lg sm:text-xl text-[#0A192F]">
                      {customer?.name || credits[0].customer_name}
                    </h3>
                    <p className="text-xs text-[#475569] font-mono mt-0.5">
                      DOCUMENTO: {customer?.document_type || docType} {customer?.document_id || docId}
                    </p>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-2 text-xs">
                  {credits[0].customer_phone && (
                    <div className="flex items-center gap-1.5 bg-[#F4F7FF] px-3 py-1.5 rounded-lg text-[#0A192F] font-medium border border-[#BFDBFE]">
                      <Phone className="w-3.5 h-3.5 text-[#0066FF]" />
                      <span>{credits[0].customer_phone}</span>
                    </div>
                  )}
                  {credits[0].customer_address && (
                    <div className="flex items-center gap-1.5 bg-[#F4F7FF] px-3 py-1.5 rounded-lg text-[#0A192F] font-medium border border-[#BFDBFE]">
                      <MapPin className="w-3.5 h-3.5 text-[#0066FF]" />
                      <span>{credits[0].customer_address}</span>
                    </div>
                  )}
                </div>
              </div>

              {/* Lista de Créditos */}
              {credits.map((credit, idx) => {
                const pendingBalance = Math.max(0, credit.total_amount - credit.paid_amount);
                const progressPct = credit.total_amount > 0 ? Math.min(100, (credit.paid_amount / credit.total_amount) * 100) : 0;
                const isPaidFull = pendingBalance <= 0 || credit.status === 'finalizado';
                const isMora = credit.status === 'mora';

                return (
                  <div key={credit.id} className="bg-white rounded-2xl border border-slate-200 card-3d-shadow overflow-hidden">
                    {/* Header del Crédito */}
                    <div className="p-5 sm:p-6 border-b border-slate-100 bg-[#F4F7FF]/70 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                      <div>
                        <div className="flex items-center gap-2.5 mb-1">
                          <span className="font-heading font-extrabold text-lg sm:text-xl text-[#0A192F]">
                            Crédito #{credits.length - idx}
                          </span>
                          <span className={`px-3 py-1 rounded-full text-xs font-extrabold ${
                            isPaidFull ? 'badge-finalizado' : isMora ? 'badge-en-mora' : 'badge-al-dia'
                          }`}>
                            {isPaidFull ? 'FINALIZADO' : isMora ? 'EN MORA' : 'AL DÍA'}
                          </span>
                        </div>
                        <p className="text-xs text-[#475569] font-medium">
                          REGISTRADO EL {formatDate(credit.created_at)} · {credit.products}
                        </p>
                      </div>

                      <div className="sm:text-right">
                        <span className="text-[10px] font-bold text-[#475569] uppercase tracking-wider block">SALDO PENDIENTE</span>
                        <span className={`font-heading font-extrabold text-2xl font-mono-finance ${
                          pendingBalance > 0 ? 'text-[#0066FF]' : 'text-[#10B981]'
                        }`}>
                          {formatCurrency(pendingBalance)}
                        </span>
                      </div>
                    </div>

                    {/* Barra de Progreso de Pago */}
                    <div className="px-5 sm:px-6 pt-5">
                      <div className="flex justify-between items-center text-xs font-bold text-[#475569] mb-1.5">
                        <span>Progreso del Pago ({progressPct.toFixed(0)}%)</span>
                        <span className="font-mono-finance">{formatCurrency(credit.paid_amount)} de {formatCurrency(credit.total_amount)}</span>
                      </div>
                      <div className="w-full bg-slate-100 rounded-full h-3 overflow-hidden shadow-inner">
                        <div 
                          className={`h-full transition-all duration-500 rounded-full ${
                            isPaidFull ? 'bg-[#10B981]' : 'bg-[#0066FF]'
                          }`}
                          style={{ width: `${progressPct}%` }}
                        />
                      </div>
                    </div>

                    {/* Resumen Métricas */}
                    <div className="p-5 sm:p-6 grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
                      <div className="bg-[#F4F7FF] p-3.5 rounded-xl border border-slate-200/80">
                        <span className="text-[10px] font-bold text-[#475569] uppercase tracking-wider block">MONTO TOTAL</span>
                        <span className="font-heading font-extrabold text-sm sm:text-base text-[#0A192F] font-mono-finance">{formatCurrency(credit.total_amount)}</span>
                      </div>
                      <div className="bg-[#F4F7FF] p-3.5 rounded-xl border border-slate-200/80">
                        <span className="text-[10px] font-bold text-[#475569] uppercase tracking-wider block">TOTAL ABONADO</span>
                        <span className="font-heading font-extrabold text-sm sm:text-base text-[#10B981] font-mono-finance">{formatCurrency(credit.paid_amount)}</span>
                      </div>
                      <div className="bg-[#F4F7FF] p-3.5 rounded-xl border border-slate-200/80">
                        <span className="text-[10px] font-bold text-[#475569] uppercase tracking-wider block">CUOTAS</span>
                        <span className="font-heading font-extrabold text-sm sm:text-base text-[#0A192F]">{credit.installments_count} ({credit.payment_frequency})</span>
                      </div>
                      <div className="bg-[#F4F7FF] p-3.5 rounded-xl border border-slate-200/80">
                        <span className="text-[10px] font-bold text-[#475569] uppercase tracking-wider block">FECHA VENCIMIENTO</span>
                        <span className="font-heading font-extrabold text-sm sm:text-base text-[#0A192F]">{formatDate(credit.due_date)}</span>
                      </div>
                    </div>

                    {/* Desglose de Cuotas & Comprobantes */}
                    <div className="px-5 sm:px-6 pb-6">
                      <h4 className="font-heading font-bold text-sm text-[#0A192F] mb-3 flex items-center gap-2 border-t border-slate-100 pt-4">
                        <Clock className="w-4 h-4 text-[#0066FF]" />
                        Plan de Cuotas e Historial de Abonos
                      </h4>

                      {!credit.installments || credit.installments.length === 0 ? (
                        <div className="p-4 bg-[#F4F7FF] rounded-xl text-xs text-[#475569] text-center">
                          No hay desglose de cuotas registrado para este crédito.
                        </div>
                      ) : (
                        <div className="overflow-x-auto rounded-xl border border-slate-200/80">
                          <table className="w-full text-left text-xs border-collapse min-w-125">
                            <thead>
                              <tr className="bg-[#F4F7FF] border-b border-slate-200 text-[#475569] font-bold uppercase tracking-wider">
                                <th className="py-3 px-3.5">Cuota #</th>
                                <th className="py-3 px-3.5">Vencimiento</th>
                                <th className="py-3 px-3.5">Monto Cuota</th>
                                <th className="py-3 px-3.5">Estado</th>
                                <th className="py-3 px-3.5 text-right">Comprobante</th>
                              </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100 bg-white">
                              {credit.installments.map((inst) => {
                                const hasReceipt = Boolean(inst.receipt_image_url && inst.receipt_image_url.trim().length > 0);

                                return (
                                  <tr key={inst.id} className="hover:bg-[#F4F7FF]/60 transition-colors">
                                    <td className="py-3 px-3.5 font-bold text-[#0A192F]">
                                      Cuota #{inst.number}
                                    </td>
                                    <td className="py-3 px-3.5 text-[#475569] font-medium">
                                      {formatDate(inst.due_date)}
                                    </td>
                                    <td className="py-3 px-3.5 font-extrabold text-[#0A192F] font-mono-finance">
                                      {formatCurrency(inst.amount)}
                                    </td>
                                    <td className="py-3 px-3.5">
                                      {inst.is_paid ? (
                                        <span className="inline-flex items-center gap-1 font-extrabold text-[#047857] bg-[#E6F7F0] px-2.5 py-0.5 rounded-md border border-[#A7F3D0] text-[11px]">
                                          <CheckCircle2 className="w-3 h-3" /> Pagado
                                        </span>
                                      ) : (
                                        <span className="inline-flex items-center gap-1 font-extrabold text-[#B91C1C] bg-[#FEE2E2] px-2.5 py-0.5 rounded-md border border-[#FECACA] text-[11px]">
                                          Pendiente
                                        </span>
                                      )}
                                    </td>
                                    <td className="py-3 px-3.5 text-right">
                                      {hasReceipt ? (
                                        <button
                                          type="button"
                                          onClick={() => setSelectedImage({
                                            url: inst.receipt_image_url!.trim(),
                                            title: `Comprobante Cuota #${inst.number} - ${customer?.name || credit.customer_name}`
                                          })}
                                          className="inline-flex items-center gap-1.5 bg-[#E6F0FF] hover:bg-[#BFDBFE] text-[#0066FF] font-bold px-3 py-1.5 rounded-lg transition-colors border border-[#BFDBFE] text-xs cursor-pointer active:scale-95"
                                          title="Ver foto del comprobante de transferencia"
                                        >
                                          <Eye className="w-3.5 h-3.5" />
                                          <span>Ver Foto</span>
                                        </button>
                                      ) : (
                                        <span className="text-slate-400 text-[11px]">-</span>
                                      )}
                                    </td>
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )
        )}
      </main>

      {/* Modal Foto de Comprobante Móvil y Desktop */}
      {selectedImage && (
        <div className="fixed inset-0 z-50 bg-[#0A192F]/80 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full overflow-hidden shadow-2xl animate-modal border border-slate-200">
            <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-[#F4F7FF]">
              <h3 className="font-heading font-bold text-sm text-[#0A192F] truncate pr-4">
                {selectedImage.title}
              </h3>
              <button
                type="button"
                onClick={() => setSelectedImage(null)}
                className="p-2 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-200/60 transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-4 bg-slate-950 flex items-center justify-center min-h-75 max-h-[75vh] overflow-auto">
              <img
                src={selectedImage.url}
                alt="Comprobante de Pago"
                className="max-w-full max-h-[70vh] object-contain rounded-lg shadow-md"
              />
            </div>
            <div className="p-3.5 bg-[#F4F7FF] border-t border-slate-100 flex justify-between items-center">
              <a
                href={selectedImage.url}
                target="_blank"
                rel="noreferrer"
                className="text-xs text-[#0066FF] hover:underline font-bold flex items-center gap-1"
              >
                <ExternalLink className="w-3.5 h-3.5" /> Abrir Imagen Completa
              </a>
              <button
                type="button"
                onClick={() => setSelectedImage(null)}
                className="bg-[#0A192F] hover:bg-slate-800 text-white font-bold text-xs px-5 py-2.5 rounded-xl transition-colors cursor-pointer"
              >
                Cerrar Ventana
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Footer & Contact Section */}
      <footer className="bg-[#0A192F] text-slate-400 text-xs py-8 border-t border-slate-800 mt-12">
        <div className="max-w-4xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2.5">
            <img src="/logo_compact.png" alt="Logo AlfaGama" className="w-12 h-12 object-contain" />
            <span className="font-bold text-white">ALFA GAMA STORE</span>
            <span className="text-slate-500">· Moda, Calidad y Estilo</span>
          </div>
          <div className="flex items-center gap-4 text-slate-300">
            <a
              href="https://wa.me/573163142258"
              target="_blank"
              rel="noreferrer"
              className="hover:text-emerald-400 flex items-center gap-1.5 transition-colors font-semibold"
            >
              <MessageSquare className="w-4 h-4 text-[#10B981]" />
              <span>Soporte WhatsApp</span>
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;
