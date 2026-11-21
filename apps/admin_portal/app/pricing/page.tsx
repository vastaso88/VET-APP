import { AdminShell } from "../../components/admin-shell";
import { PricingPanel } from "../../components/pricing-panel";
import { getAdminTotpEnabled } from "../../lib/admin-mfa";
import { getAdminPricing } from "../../lib/admin-api";

export default async function PricingPage() {
  const [pricing, totpEnabled] = await Promise.all([
    getAdminPricing().catch(() => null),
    getAdminTotpEnabled().catch(() => null),
  ]);
  return (
    <AdminShell title="Pricing" eyebrow="Billing / Catalogo commerciale">
      {pricing ? (
        <PricingPanel initial={pricing} totpEnabled={totpEnabled} />
      ) : (
        <section className="panel">
          <h2>Configurazione PRICING non disponibile</h2>
          <p className="muted">
            Verifica che la migrazione 20261121230000_admin_pricing.sql sia stata
            applicata al database e che il backend aggiornato sia in esecuzione.
            Nessun valore mancante viene interpretato come un prezzo attivo.
          </p>
        </section>
      )}
    </AdminShell>
  );
}
