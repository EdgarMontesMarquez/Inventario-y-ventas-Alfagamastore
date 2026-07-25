export interface Customer {
  id: string;
  name: string;
  phone: string;
  address: string;
  document_type: string;
  document_id: string;
}

export interface CreditInstallment {
  id: string;
  credit_id: string;
  number: number;
  amount: number;
  paid_amount: number;
  due_date: string;
  is_paid: boolean;
  paid_at?: string;
  payment_method?: string;
  notes?: string;
  receipt_image_url?: string;
}

export interface Credit {
  id: string;
  customer_id?: string;
  customer_name: string;
  customer_phone: string;
  customer_address: string;
  products: string;
  total_amount: number;
  paid_amount: number;
  interest_rate: number;
  interest_amount: number;
  installments_count: number;
  payment_frequency: string;
  status: 'activo' | 'mora' | 'finalizado' | string;
  due_date: string;
  notes?: string;
  created_at: string;
  installments: CreditInstallment[];
}
