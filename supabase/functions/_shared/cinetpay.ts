// ═══════════════════════════════════════════════════════════════════════════
// _shared/cinetpay.ts — Interface PaymentProvider + implémentation CinetPay
// Les clés API ne vivent QUE dans Deno.env (Supabase Vault)
// ═══════════════════════════════════════════════════════════════════════════

export interface InitiateParams {
  amount: number;
  currency: string;
  operator: 'moov' | 'airtel';
  phoneNumber: string;
  reference: string;      // UUID généré par notre backend
  description: string;
  notifyUrl: string;      // URL du webhook
  returnUrl?: string;
}

export interface InitiateResult {
  success: boolean;
  providerReference?: string;
  paymentUrl?: string;
  rawResponse?: unknown;
  error?: string;
}

export type PaymentStatusResult = 'pending' | 'paid' | 'failed';

export interface PaymentProvider {
  initiate(params: InitiateParams): Promise<InitiateResult>;
  checkStatus(reference: string): Promise<PaymentStatusResult>;
}

// ─── Implémentation CinetPay ─────────────────────────────────────────────────

export class CinetPayProvider implements PaymentProvider {
  private readonly apiKey: string;
  private readonly siteId: string;
  private readonly baseUrl = 'https://api-checkout.cinetpay.com/v2';

  constructor() {
    this.apiKey = Deno.env.get('CINETPAY_API_KEY') ?? '';
    this.siteId = Deno.env.get('CINETPAY_SITE_ID') ?? '';
    if (!this.apiKey || !this.siteId) {
      throw new Error('CINETPAY_API_KEY and CINETPAY_SITE_ID must be set');
    }
  }

  async initiate(params: InitiateParams): Promise<InitiateResult> {
    try {
      const payload = {
        apikey: this.apiKey,
        site_id: this.siteId,
        transaction_id: params.reference,
        amount: params.amount,
        currency: params.currency,
        description: params.description,
        return_url: params.returnUrl ?? '',
        notify_url: params.notifyUrl,
        // CinetPay mobile money params
        channels: params.operator === 'moov' ? 'MOBILE_MONEY' : 'MOBILE_MONEY',
        metadata: JSON.stringify({ operator: params.operator }),
        // Numéro du payeur pour les paiements directs
        customer_phone_number: params.phoneNumber,
        customer_name: 'FALE Archives',
        customer_email: 'noreply@falearchives.com',
        customer_surname: 'Client',
      };

      const res = await fetch(`${this.baseUrl}/payment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const json = await res.json() as Record<string, unknown>;

      if (json['code'] === '201') {
        const data = json['data'] as Record<string, string>;
        return {
          success: true,
          providerReference: data['transaction_id'],
          paymentUrl: data['payment_url'],
          rawResponse: json,
        };
      }

      return {
        success: false,
        error: `CinetPay error: ${json['message'] ?? 'Unknown error'}`,
        rawResponse: json,
      };
    } catch (e) {
      return { success: false, error: `Network error: ${e}` };
    }
  }

  async checkStatus(reference: string): Promise<PaymentStatusResult> {
    try {
      const payload = {
        apikey: this.apiKey,
        site_id: this.siteId,
        transaction_id: reference,
      };

      const res = await fetch(`${this.baseUrl}/payment/check`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const json = await res.json() as Record<string, unknown>;
      const data = json['data'] as Record<string, string> | undefined;
      const status = data?.['status'];

      // Mapping des statuts CinetPay → statuts internes
      if (status === 'ACCEPTED') return 'paid';
      if (status === 'REFUSED' || status === 'FAILED') return 'failed';
      return 'pending'; // CREATED, PENDING, etc.
    } catch (_) {
      return 'pending';
    }
  }
}

// Factory — permet d'ajouter facilement d'autres providers
export function createPaymentProvider(): PaymentProvider {
  return new CinetPayProvider();
}
