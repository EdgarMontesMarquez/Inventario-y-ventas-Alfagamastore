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
  Building2,
  Clock,
  Sparkles
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

  // Auto-cargar si viene por URL (ej: ?doc_type=CC&doc_id=1107858381)
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
    const cleanId = idToUse.trim();
    if (!cleanId) {
      setErrorMsg('Por favor ingrese el número de documento.');
      return;
    }

    setLoading(true);
    setErrorMsg(null);
    setSearched(true);
    setCustomer(null);
    setCredits([]);

    try {
      // 1. Buscar Cliente por Documento
      let foundCustomer: Customer | null = null;
      const { data: customerData, error: custError } = await supabase
        .from('customers')
        .select('*')
        .or(`and(document_type.eq.${typeToUse},document_id.eq.${cleanId}),document_id.eq.${cleanId},phone.eq.${cleanId}`)
        .limit(1)
        .maybeSingle();

      if (!custError && customerData) {
        foundCustomer = {
          id: customerData.id,
          name: customerData.name,
          phone: customerData.phone,
          address: customerData.address,
          document_type: customerData.document_type || typeToUse,
          document_id: customerData.document_id || cleanId
        };
        setCustomer(foundCustomer);
      }

      // 2. Buscar Créditos del Cliente
      let creditsQuery = supabase.from('credits').select('*');
      if (foundCustomer) {
        creditsQuery = creditsQuery.or(`customer_id.eq.${foundCustomer.id},customer_name.ilike.%${foundCustomer.name}%`);
      } else {
        creditsQuery = creditsQuery.or(`notes.ilike.%${cleanId}%,customer_phone.eq.${cleanId}`);
      }

      const { data: creditsData, error: credError } = await creditsQuery.order('created_at', { ascending: false });

      if (credError) {
        throw new Error('Error consultando créditos en el sistema.');
      }

      if (!creditsData || creditsData.length === 0) {
        setLoading(false);
        return;
      }

      // 3. Cargar Cuotas (Installments) para cada crédito
      const fullCredits: Credit[] = await Promise.all(
        creditsData.map(async (c: Record<string, any>) => {
          const { data: instData } = await supabase
            .from('credit_installments')
            .select('*')
            .eq('credit_id', c.id)
            .order('number', { ascending: true });

          const totalAmt = Number(c.total_amount || 0);
          const paidAmt = Number(c.paid_amount || 0);

          return {
            id: c.id,
            customer_id: c.customer_id,
            customer_name: c.customer_name || foundCustomer?.name || 'Cliente',
            customer_phone: c.customer_phone || foundCustomer?.phone,
            customer_address: c.customer_address || foundCustomer?.address,
            products: c.products || 'Productos AlfaGama',
            total_amount: totalAmt,
            paid_amount: paidAmt,
            interest_rate: Number(c.interest_rate || 0),
            interest_amount: Number(c.interest_amount || 0),
            installments_count: Number(c.installments_count || 1),
            payment_frequency: c.payment_frequency || 'mensual',
            status: c.status || (paidAmt >= totalAmt ? 'finalizado' : 'activo'),
            due_date: c.due_date || new Date().toISOString(),
            notes: c.notes,
            created_at: c.created_at,
            installments: (instData || []).map((inst: Record<string, any>) => ({
              id: inst.id,
              credit_id: inst.credit_id,
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
      setErrorMsg(err.message || 'No se pudo conectar con el sistema. Intente de nuevo.');
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
    <div className="min-h-screen bg-slate-50 text-slate-800 flex flex-col justify-between">
      {/* Header Bar */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-sm">
        <div className="max-w-4xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-indigo-600 flex items-center justify-center text-white shadow-md shadow-indigo-200 font-heading font-extrabold text-xl">
              α
            </div>
            <div>
              <h1 className="font-heading font-bold text-lg text-slate-900 leading-tight">ALFA GAMA STORE</h1>
              <p className="text-xs text-indigo-600 font-semibold tracking-wider uppercase">PORTAL DE CRÉDITOS Y PAGOS</p>
            </div>
          </div>
          <div className="hidden sm:flex items-center gap-2 text-xs text-slate-500 bg-slate-100 px-3 py-1.5 rounded-full">
            <ShieldCheck className="w-4 h-4 text-emerald-600" />
            <span>Consulta Segura 24/7</span>
          </div>
        </div>
      </header>

      {/* Main Content Container */}
      <main className="max-w-4xl mx-auto px-4 py-8 w-full flex-grow">
        {/* Banner de Bienvenida y Formulario de Búsqueda */}
        <div className="glass-card rounded-2xl p-6 sm:p-8 mb-8 border border-slate-200 shadow-xl">
          <div className="text-center max-w-xl mx-auto mb-6">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-indigo-50 text-indigo-700 mb-3 border border-indigo-100">
              <Sparkles className="w-3.5 h-3.5" /> Estado de Cuenta en Tiempo Real
            </span>
            <h2 className="font-heading font-extrabold text-2xl sm:text-3xl text-slate-900 mb-2">
              Consulta tu Historial de Crédito
            </h2>
            <p className="text-slate-500 text-sm">
              Ingresa tu tipo y número de documento registrado para consultar saldos, fechas de pago y comprobantes.
            </p>
          </div>

          {/* Formulario */}
          <form 
            onSubmit={(e) => {
              e.preventDefault();
              handleSearch();
            }}
            className="flex flex-col sm:flex-row gap-3 max-w-2xl mx-auto"
          >
            {/* Selector de Tipo de Documento */}
            <div className="w-full sm:w-48">
              <label className="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">
                TIPO DOC.
              </label>
              <select
                value={docType}
                onChange={(e) => setDocType(e.target.value)}
                className="w-full bg-white border border-slate-300 rounded-xl px-3.5 py-3 text-sm font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 shadow-sm"
              >
                <option value="CC">Cédula Ciudadanía (CC)</option>
                <option value="CE">Cédula Extranjería (CE)</option>
                <option value="NIT">NIT / RUT</option>
                <option value="PAS">Pasaporte</option>
              </select>
            </div>

            {/* Input Número de Documento */}
            <div className="flex-1">
              <label className="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">
                NÚMERO DE DOCUMENTO
              </label>
              <div className="relative">
                <input
                  type="text"
                  placeholder="Ej: 1107858381"
                  value={docId}
                  onChange={(e) => setDocId(e.target.value)}
                  className="w-full bg-white border border-slate-300 rounded-xl pl-4 pr-10 py-3 text-sm font-semibold text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 shadow-sm"
                />
                {docId && (
                  <button
                    type="button"
                    onClick={() => setDocId('')}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-1"
                  >
                    <X className="w-4 h-4" />
                  </button>
                )}
              </div>
            </div>

            {/* Botón Buscar */}
            <div className="sm:self-end w-full sm:w-auto">
              <button
                type="submit"
                disabled={loading}
                className="w-full sm:w-auto bg-indigo-600 hover:bg-indigo-700 text-white font-bold px-6 py-3 rounded-xl transition-all duration-200 flex items-center justify-center gap-2 shadow-lg shadow-indigo-200 active:scale-95 disabled:opacity-50"
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
          </form>

          {errorMsg && (
            <div className="mt-4 p-3 bg-red-50 border border-red-200 text-red-700 text-xs font-semibold rounded-xl flex items-center gap-2 max-w-2xl mx-auto">
              <AlertTriangle className="w-4 h-4 flex-shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}
        </div>

        {/* Resultados de la Consulta */}
        {searched && !loading && (
          credits.length === 0 ? (
            <div className="bg-white rounded-2xl p-12 text-center border border-slate-200 shadow-sm">
              <div className="w-16 h-16 bg-slate-100 text-slate-400 rounded-full flex items-center justify-center mx-auto mb-4">
                <CreditCard className="w-8 h-8" />
              </div>
              <h3 className="font-heading font-bold text-xl text-slate-800 mb-1">Sin créditos registrados</h3>
              <p className="text-slate-500 text-sm max-w-md mx-auto">
                No se encontraron créditos asociados al documento <strong className="text-slate-800">{docType} {docId}</strong>. Verifica el número ingresado o comunícate con la tienda.
              </p>
            </div>
          ) : (
            <div className="space-y-6">
              {/* Tarjeta de Información del Cliente */}
              <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                <div>
                  <span className="text-xs font-bold text-indigo-600 uppercase tracking-wider">CLIENTE TITULAR</span>
                  <h3 className="font-heading font-extrabold text-xl text-slate-900">
                    {customer?.name || credits[0].customer_name}
                  </h3>
                  <p className="text-xs text-slate-500 font-mono mt-0.5">
                    DOCUMENTO: {customer?.document_type || docType} {customer?.document_id || docId}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-3 text-xs">
                  {credits[0].customer_phone && (
                    <div className="flex items-center gap-1.5 bg-slate-100 px-3 py-1.5 rounded-lg text-slate-700 font-medium">
                      <Phone className="w-3.5 h-3.5 text-indigo-600" />
                      <span>{credits[0].customer_phone}</span>
                    </div>
                  )}
                  {credits[0].customer_address && (
                    <div className="flex items-center gap-1.5 bg-slate-100 px-3 py-1.5 rounded-lg text-slate-700 font-medium">
                      <MapPin className="w-3.5 h-3.5 text-indigo-600" />
                      <span>{credits[0].customer_address}</span>
                    </div>
                  )}
                </div>
              </div>

              {/* Lista de Créditos del Cliente */}
              {credits.map((credit, idx) => {
                const pendingBalance = Math.max(0, credit.total_amount - credit.paid_amount);
                const progressPct = credit.total_amount > 0 ? Math.min(100, (credit.paid_amount / credit.total_amount) * 100) : 0;
                const isPaidFull = pendingBalance <= 0 || credit.status === 'finalizado';
                const isMora = credit.status === 'mora';

                return (
                  <div key={credit.id} className="bg-white rounded-2xl border border-slate-200 shadow-md overflow-hidden">
                    {/* Encabezado del Crédito */}
                    <div className="p-6 border-b border-slate-100 bg-slate-50/50 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                      <div>
                        <div className="flex items-center gap-2 mb-1">
                          <span className="font-heading font-bold text-lg text-slate-900">
                            Crédito #{credits.length - idx}
                          </span>
                          <span className={`px-2.5 py-0.5 rounded-full text-xs font-bold ${
                            isPaidFull ? 'badge-finalizado' : isMora ? 'badge-mora' : 'badge-activo'
                          }`}>
                            {isPaidFull ? 'FINALIZADO' : isMora ? 'EN MORA' : 'AL DÍA'}
                          </span>
                        </div>
                        <p className="text-xs text-slate-500">
                          REGISTRADO EL {formatDate(credit.created_at)} · {credit.products}
                        </p>
                      </div>

                      <div className="text-right">
                        <span className="text-xs text-slate-500 font-medium block">SALDO PENDIENTE</span>
                        <span className={`font-heading font-extrabold text-2xl ${
                          pendingBalance > 0 ? 'text-indigo-600' : 'text-emerald-600'
                        }`}>
                          {formatCurrency(pendingBalance)}
                        </span>
                      </div>
                    </div>

                    {/* Barra de Progreso de Pago */}
                    <div className="px-6 pt-4">
                      <div className="flex justify-between items-center text-xs font-semibold text-slate-500 mb-1.5">
                        <span>Progreso de Pago ({progressPct.toFixed(0)}%)</span>
                        <span>{formatCurrency(credit.paid_amount)} de {formatCurrency(credit.total_amount)}</span>
                      </div>
                      <div className="w-full bg-slate-100 rounded-full h-2.5 overflow-hidden">
                        <div 
                          className={`h-full transition-all duration-500 rounded-full ${
                            isPaidFull ? 'bg-emerald-500' : 'bg-indigo-600'
                          }`}
                          style={{ width: `${progressPct}%` }}
                        />
                      </div>
                    </div>

                    {/* Resumen Métricas */}
                    <div className="p-6 grid grid-cols-2 sm:grid-cols-4 gap-4">
                      <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">MONTO TOTAL</span>
                        <span className="font-heading font-bold text-base text-slate-800">{formatCurrency(credit.total_amount)}</span>
                      </div>
                      <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">TOTAL ABONADO</span>
                        <span className="font-heading font-bold text-base text-emerald-600">{formatCurrency(credit.paid_amount)}</span>
                      </div>
                      <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">CUOTAS</span>
                        <span className="font-heading font-bold text-base text-slate-800">{credit.installments_count} ({credit.payment_frequency})</span>
                      </div>
                      <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">VENCIMIENTO</span>
                        <span className="font-heading font-bold text-base text-slate-800">{formatDate(credit.due_date)}</span>
                      </div>
                    </div>

                    {/* Desglose de Cuotas e Historial de Abonos */}
                    <div className="px-6 pb-6">
                      <h4 className="font-heading font-bold text-sm text-slate-800 mb-3 flex items-center gap-2">
                        <Clock className="w-4 h-4 text-indigo-600" />
                        Plan de Cuotas e Historial de Abonos
                      </h4>

                      {!credit.installments || credit.installments.length === 0 ? (
                        <div className="p-4 bg-slate-50 rounded-xl text-xs text-slate-500 text-center">
                          No hay desglose de cuotas registrado para este crédito.
                        </div>
                      ) : (
                        <div className="overflow-x-auto">
                          <table className="w-full text-left text-xs border-collapse">
                            <thead>
                              <tr className="border-b border-slate-200 text-slate-500 font-bold uppercase tracking-wider">
                                <th className="py-2.5 px-3">Cuota #</th>
                                <th className="py-2.5 px-3">Vencimiento</th>
                                <th className="py-2.5 px-3">Monto Cuota</th>
                                <th className="py-2.5 px-3">Estado</th>
                                <th className="py-2.5 px-3">Fecha Pago</th>
                                <th className="py-2.5 px-3 text-right">Comprobante</th>
                              </tr>
                            </thead>
                            <tbody className="divide-y divide-slate-100">
                              {credit.installments.map((inst) => {
                                const hasReceipt = Boolean(inst.receipt_image_url && inst.receipt_image_url.trim().length > 0);

                                return (
                                  <tr key={inst.id} className="hover:bg-slate-50/80 transition-colors">
                                    <td className="py-3 px-3 font-bold text-slate-800">
                                      Cuota #{inst.number}
                                    </td>
                                    <td className="py-3 px-3 text-slate-600 font-medium">
                                      {formatDate(inst.due_date)}
                                    </td>
                                    <td className="py-3 px-3 font-bold text-slate-900">
                                      {formatCurrency(inst.amount)}
                                    </td>
                                    <td className="py-3 px-3">
                                      {inst.is_paid ? (
                                        <span className="inline-flex items-center gap-1 font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200 text-[11px]">
                                          <CheckCircle2 className="w-3 h-3" /> Pagado
                                        </span>
                                      ) : (
                                        <span className="inline-flex items-center gap-1 font-semibold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-md border border-amber-200 text-[11px]">
                                          Pendiente
                                        </span>
                                      )}
                                    </td>
                                    <td className="py-3 px-3 text-slate-500">
                                      {inst.paid_at ? formatDate(inst.paid_at) : '-'}
                                    </td>
                                    <td className="py-3 px-3 text-right">
                                      {hasReceipt ? (
                                        <button
                                          type="button"
                                          onClick={() => setSelectedImage({
                                            url: inst.receipt_image_url!.trim(),
                                            title: `Comprobante Cuota #${inst.number} - ${customer?.name || credit.customer_name}`
                                          })}
                                          className="inline-flex items-center gap-1 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold px-2.5 py-1 rounded-lg transition-colors border border-indigo-200"
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

      {/* Modal de Visualización de Foto de Comprobante */}
      {selectedImage && (
        <div className="fixed inset-0 z-50 bg-slate-900/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full overflow-hidden shadow-2xl animate-modal border border-slate-200">
            <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
              <h3 className="font-heading font-bold text-sm text-slate-800 truncate pr-4">
                {selectedImage.title}
              </h3>
              <button
                type="button"
                onClick={() => setSelectedImage(null)}
                className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-200/50 transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-4 bg-slate-950 flex items-center justify-center min-h-[300px] max-h-[75vh] overflow-auto">
              <img
                src={selectedImage.url}
                alt="Comprobante de Pago"
                className="max-w-full max-h-[70vh] object-contain rounded-lg shadow-md"
                onError={(e) => {
                  (e.target as HTMLElement).style.display = 'none';
                }}
              />
            </div>
            <div className="p-3 bg-slate-50 border-t border-slate-100 text-center">
              <button
                type="button"
                onClick={() => setSelectedImage(null)}
                className="bg-slate-800 hover:bg-slate-900 text-white font-bold text-xs px-5 py-2 rounded-xl transition-colors"
              >
                Cerrar Ventana
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Footer & Contact Section */}
      <footer className="bg-slate-900 text-slate-400 text-xs py-8 border-t border-slate-800 mt-12">
        <div className="max-w-4xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <Building2 className="w-4 h-4 text-indigo-400" />
            <span className="font-semibold text-slate-200">ALFA GAMA STORE</span>
            <span>· Moda, Calidad y Estilo</span>
          </div>
          <div className="flex items-center gap-4 text-slate-300">
            <a
              href="https://wa.me/573001234567"
              target="_blank"
              rel="noreferrer"
              className="hover:text-emerald-400 flex items-center gap-1.5 transition-colors"
            >
              <MessageSquare className="w-4 h-4 text-emerald-500" />
              <span>Soporte por WhatsApp</span>
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;
