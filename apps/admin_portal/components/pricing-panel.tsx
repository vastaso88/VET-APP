"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  type PricingFeature, type PricingFeatureKey, type PricingPlan,
  type PricingPrice, type PricingSnapshot, type PricingStore,
  type PricingPeriod,
} from "../lib/admin-api";
import { savePricingFeature, savePricingPrice } from "../app/pricing/actions";
import {
  beginPlanTotpSetup, completePlanTotpSetup,
} from "../app/users/actions";

const plans: PricingPlan[] = ["plus", "pro", "ultra"];
const featureLabels: { key: PricingFeatureKey; label: string; detail: string }[] = [
  { key: "max_pets", label: "Animali attivi", detail: "I Ricordi non occupano posti" },
  { key: "max_chats_per_pet", label: "Chat per animale", detail: "Numero massimo di conversazioni" },
  { key: "daily_questions", label: "Domande AI/giorno", detail: "Quota giornaliera" },
  { key: "daily_sonnet_answers", label: "Risposte Sonnet/giorno", detail: "Modello avanzato" },
  { key: "max_devices", label: "Dispositivi", detail: "Nuove registrazioni" },
];
const currencies = ["EUR", "USD", "GBP", "CHF", "AUD", "CAD"];
const defaultCurrency: Record<string, string> = {
  IT: "EUR", DE: "EUR", AT: "EUR", FR: "EUR", ES: "EUR",
  GB: "GBP", US: "USD", AU: "AUD", CH: "CHF", CA: "CAD",
};
type PriceEdit = PricingPrice & { amountText: string };
const keyFor = (item: { country_code: string; store: string; plan: string; period: string }) =>
  [item.country_code, item.store, item.plan, item.period].join(":");
const featureId = (item: { plan: string; feature: string }) => item.plan + ":" + item.feature;
const minor = (amount: string): number | null => {
  if (!/^\d{1,7}(?:[.,]\d{1,2})?$/.test(amount.trim())) return null;
  const n = Number(amount.replace(",", "."));
  const rounded = Math.round(n * 100);
  return rounded > 0 && rounded <= 100_000_000 ? rounded : null;
};
const display = (priceMinor: number) => (priceMinor / 100).toFixed(2);
const toEditable = (price: PricingPrice): PriceEdit => ({
  ...price, amountText: display(price.amount_minor),
});

export function PricingPanel({
  initial,
  totpEnabled: initiallyEnabled,
}: {
  initial: PricingSnapshot;
  totpEnabled: boolean;
}) {
  const router = useRouter();
  const [features, setFeatures] = useState(initial.features);
  const [savedFeatures, setSavedFeatures] = useState(initial.features);
  const [prices, setPrices] = useState<PriceEdit[]>(initial.prices.map(toEditable));
  const [savedPrices, setSavedPrices] = useState<PriceEdit[]>(initial.prices.map(toEditable));
  const [tab, setTab] = useState<"features" | "prices">("prices");
  const [countryFilter, setCountryFilter] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState("");
  const [message, setMessage] = useState("");
  const [totpEnabled, setTotpEnabled] = useState(initiallyEnabled);
  const [setup, setSetup] = useState<{ factorId: string; qrDataUrl: string; secret: string } | null>(null);
  const [setupCode, setSetupCode] = useState("");
  const [newPrice, setNewPrice] = useState({
    country_code: "IT", store: "apple" as PricingStore,
    plan: "plus" as PricingPlan, period: "monthly" as PricingPeriod,
    currency: "EUR", amountText: "",
  });

  useEffect(() => {
    setFeatures(initial.features);
    setSavedFeatures(initial.features);
    setPrices(initial.prices.map(toEditable));
    setSavedPrices(initial.prices.map(toEditable));
  }, [initial]);

  const ready = totpEnabled && /^\d{6}$/.test(code) && !busy;
  const canSubmit = (id: string) => ready && busy !== id;

  async function saveFeature(row: PricingFeature) {
    const id = "feature-" + featureId(row);
    if (!canSubmit(id)) return;
    setBusy(id); setMessage("");
    try {
      const result = await savePricingFeature({
        plan: row.plan, feature: row.feature, enabled: row.enabled,
        quota: row.quota, totp_code: code,
      });
      if (!result.ok) {
        setMessage(result.error);
      } else {
        setSavedFeatures(items => items.map(item =>
          featureId(item) === featureId(row) ? { ...row } : item
        ));
        setMessage("Funzione salvata. Inserisci un nuovo codice TOTP per il prossimo intervento.");
        router.refresh();
      }
    } catch {
      setMessage("Impossibile aggiornare la funzionalità.");
    } finally {
      setCode(""); setBusy("");
    }
  }

  async function savePrice(row: PriceEdit, remove = false) {
    const id = "price-" + keyFor(row);
    if (!canSubmit(id)) return;
    const amount_minor = remove ? null : minor(row.amountText);
    if (!remove && amount_minor === null) {
      setMessage("Prezzo non valido: utilizza un importo positivo con massimo due decimali.");
      return;
    }
    setBusy(id); setMessage("");
    try {
      const result = await savePricingPrice({
        country_code: row.country_code, store: row.store,
        plan: row.plan, period: row.period, currency: row.currency,
        amount_minor, totp_code: code,
      });
      if (!result.ok) {
        setMessage(result.error);
      } else {
        if (remove) {
          setPrices(items => items.filter(item => keyFor(item) !== keyFor(row)));
          setSavedPrices(items => items.filter(item => keyFor(item) !== keyFor(row)));
        } else {
          const updated: PriceEdit = { ...row, amount_minor: amount_minor!, amountText: display(amount_minor!) };
          setPrices(items => items.map(item => keyFor(item) === keyFor(row) ? updated : item));
          setSavedPrices(items => items.map(item => keyFor(item) === keyFor(row) ? updated : item));
        }
        setMessage("Prezzo obiettivo salvato nel catalogo interno; lo store NON è stato aggiornato.");
        router.refresh();
      }
    } catch {
      setMessage("Impossibile salvare il prezzo.");
    } finally {
      setCode(""); setBusy("");
    }
  }

  async function addPrice() {
    const row: PriceEdit = {
      ...newPrice, country_code: newPrice.country_code.trim().toUpperCase(),
      amount_minor: minor(newPrice.amountText) ?? 0, updated_at: "",
    };
    if (!/^[A-Z]{2}$/.test(row.country_code) || !/^[A-Z]{3}$/.test(row.currency)) {
      setMessage("Paese ISO a due lettere e valuta a tre lettere obbligatori.");
      return;
    }
    if (prices.some(item => keyFor(item) === keyFor(row))) {
      setMessage("Prezzo già presente: modificalo nella tabella.");
      return;
    }
    if (minor(row.amountText) === null) {
      setMessage("Inserisci un prezzo valido.");
      return;
    }
    if (!ready) {
      setMessage("Inserisci un codice TOTP non ancora utilizzato.");
      return;
    }
    setBusy("new-price"); setMessage("");
    try {
      const result = await savePricingPrice({
        country_code: row.country_code, store: row.store, plan: row.plan,
        period: row.period, currency: row.currency, amount_minor: row.amount_minor,
        totp_code: code,
      });
      if (!result.ok) {
        setMessage(result.error);
      } else {
        setPrices(items => [...items, row]);
        setSavedPrices(items => [...items, row]);
        setNewPrice(input => ({ ...input, amountText: "" }));
        setMessage("Nuovo prezzo obiettivo salvato; resta da configurare in App Store Connect/Play Console.");
        router.refresh();
      }
    } catch {
      setMessage("Impossibile creare il prezzo.");
    } finally {
      setCode(""); setBusy("");
    }
  }

  async function beginSetup() {
    setBusy("setup"); setMessage("");
    try {
      const result = await beginPlanTotpSetup();
      if (!result.ok) setMessage(result.error);
      else if (result.result.status === "already_enabled") setTotpEnabled(true);
      else setSetup(result.result);
    } catch {
      setMessage("Configurazione TOTP non disponibile.");
    } finally { setBusy(""); }
  }

  async function completeSetup() {
    if (!setup || !/^\d{6}$/.test(setupCode)) return;
    setBusy("setup"); setMessage("");
    try {
      const result = await completePlanTotpSetup(setup.factorId, setupCode);
      if (!result.ok) setMessage(result.error);
      else {
        setSetup(null); setSetupCode(""); setTotpEnabled(true);
        setMessage("TOTP attivato. Usa un nuovo codice per ogni salvataggio.");
        router.refresh();
      }
    } catch {
      setMessage("Attivazione TOTP non riuscita.");
    } finally { setBusy(""); }
  }

  return (
    <>
      <section className="panel pricing-security">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Protezione delle modifiche</p>
            <h2>Conferma TOTP ad ogni salvataggio</h2>
          </div>
          <span className="tag">{totpEnabled ? "Authenticator attivo" : "TOTP da configurare"}</span>
        </div>
        {totpEnabled ? (
          <label className="pricing-code">
            Codice di autenticazione (6 cifre)
            <input
              value={code} onChange={event => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
              inputMode="numeric" autoComplete="one-time-code" maxLength={6}
              placeholder="000000" aria-label="Codice TOTP per il prossimo salvataggio"
            />
          </label>
        ) : !setup ? (
          <button className="primary-button" type="button" disabled={!!busy} onClick={() => void beginSetup()}>
            Configura Authenticator
          </button>
        ) : (
          <div className="pricing-enrollment">
            <p>Scansiona il QR con un'app Authenticator. Non condividere questa chiave.</p>
            <img src={setup.qrDataUrl} width={180} height={180} alt="QR per configurare TOTP" />
            <p>Chiave manuale: <code>{setup.secret}</code></p>
            <input
              value={setupCode} onChange={event => setSetupCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
              inputMode="numeric" autoComplete="one-time-code" maxLength={6}
              placeholder="Codice di attivazione" aria-label="Codice di attivazione TOTP"
            />
            <button type="button" className="primary-button" disabled={!!busy || setupCode.length !== 6}
              onClick={() => void completeSetup()}>Attiva TOTP</button>
          </div>
        )}
        <p className="muted">Il codice viene verificato dal backend ed è utilizzabile una sola volta. Dopo ogni intervento serve un nuovo codice.</p>
        {message && <p role="status" className="pricing-message">{message}</p>}
      </section>

      <nav className="pricing-tabs" aria-label="Sezioni Pricing">
        <button type="button" className={tab === "prices" ? "active" : ""}
          onClick={() => setTab("prices")}>Prezzi per Paese</button>
        <button type="button" className={tab === "features" ? "active" : ""}
          onClick={() => setTab("features")}>Funzioni e quote</button>
      </nav>

      {tab === "features" ? (
        <section className="panel">
          <div className="panel-heading">
            <div><p className="eyebrow">Entitlements del backend</p><h2>Funzioni per piano</h2></div>
          </div>
          <p className="muted">
            Spunta per abilitare. Se disabiliti una funzione, il limite effettivo diventa zero,
            ma la quota impostata resta memorizzata. Le modifiche vengono applicate dal backend;
            il limite degli animali è applicato anche alle scritture Supabase.
          </p>
          <div className="pricing-scroll">
            <table className="pricing-table pricing-features">
              <thead><tr><th>Funzione</th>{plans.map(p => <th key={p}>{p.toUpperCase()}</th>)}</tr></thead>
              <tbody>
                {featureLabels.map(item => (
                  <tr key={item.key}>
                    <th scope="row"><strong>{item.label}</strong><small>{item.detail}</small></th>
                    {plans.map(plan => {
                      const row = features.find(f => f.plan === plan && f.feature === item.key);
                      if (!row) return <td key={plan}>Non configurato</td>;
                      const saved = savedFeatures.find(f => featureId(f) === featureId(row));
                      const changed = row.enabled !== saved?.enabled || row.quota !== saved?.quota;
                      const id = featureId(row);
                      return (
                        <td key={id}>
                          <div className="pricing-feature-cell">
                            <label className="pricing-check">
                              <input type="checkbox" checked={row.enabled} disabled={!!busy}
                                onChange={e => setFeatures(items => items.map(f =>
                                  featureId(f) === id ? { ...f, enabled: e.target.checked } : f
                                ))} />
                              {row.enabled ? "Attiva" : "Disattiva"}
                            </label>
                            <label>
                              Quota
                              <input type="number" min={0} max={2000} step={1} value={row.quota} disabled={!!busy}
                                onChange={e => setFeatures(items => items.map(f =>
                                  featureId(f) === id ? { ...f, quota: Math.max(0, Math.min(2000, Number(e.target.value) || 0)) } : f
                                ))} />
                            </label>
                            <button type="button" disabled={!changed || !ready || !!busy}
                              onClick={() => void saveFeature(row)}>
                              {busy === "feature-" + id ? "Salvataggio…" : changed ? "Salva *" : "Salvato"}
                            </button>
                          </div>
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="muted">* Richiede TOTP. Attenzione: la disattivazione può incidere immediatamente anche su abbonati esistenti.</p>
        </section>
      ) : (
        <>
          <section className="panel">
            <div className="panel-heading">
              <div><p className="eyebrow">Listino per mercato e piattaforma</p><h2>Prezzi obiettivo degli store</h2></div>
            </div>
            <p className="muted">
              I valori qui sotto sono bozze interne, non prezzi degli abbonamenti in vendita.
              I prezzi effettivi vengono restituiti da Apple e Google; questo pannello NON
              li modifica e non sincronizza automaticamente i listini.
            </p>
            <div className="pricing-filter">
              <label>Filtra Paese
                <input value={countryFilter} maxLength={2} placeholder="Tutti (es. IT)"
                  onChange={event => setCountryFilter(event.target.value.toUpperCase().replace(/[^A-Z]/g, ""))} />
              </label>
              <span className="tag">{prices.length} prezzi obiettivo</span>
            </div>
            <div className="pricing-scroll">
              <table className="pricing-table">
                <thead><tr>
                  <th>Paese</th><th>Store</th><th>Piano</th><th>Durata</th>
                  <th>Valuta</th><th>Importo</th><th>Azione protetta</th>
                </tr></thead>
                <tbody>
                  {prices.filter(p => !countryFilter || p.country_code === countryFilter).map(row => {
                    const id = keyFor(row);
                    const saved = savedPrices.find(p => keyFor(p) === id);
                    const changed = row.currency !== saved?.currency ||
                      minor(row.amountText) !== saved?.amount_minor;
                    return (
                      <tr key={id}>
                        <td>{row.country_code}</td><td>{row.store}</td>
                        <td>{row.plan.toUpperCase()}</td><td>{row.period === "monthly" ? "Mensile" : "Annuale"}</td>
                        <td><select value={row.currency} disabled={!!busy}
                          onChange={event => setPrices(items => items.map(p => keyFor(p) === id ?
                            { ...p, currency: event.target.value } : p))}>
                          {currencies.map(c => <option key={c} value={c}>{c}</option>)}
                        </select></td>
                        <td><input type="text" inputMode="decimal" value={row.amountText} disabled={!!busy}
                          onChange={event => setPrices(items => items.map(p => keyFor(p) === id ?
                            { ...p, amountText: event.target.value } : p))} aria-label={"Importo " + id}/></td>
                        <td className="pricing-actions">
                          <button type="button" disabled={!changed || !ready || !!busy}
                            onClick={() => void savePrice(row)}>Salva</button>
                          <button type="button" disabled={!ready || !!busy}
                            onClick={() => void savePrice(row, true)}>Rimuovi</button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </section>
          <section className="panel">
            <h2>Aggiungi un prezzo per un mercato</h2>
            <div className="pricing-add">
              <label>Paese ISO
                <input value={newPrice.country_code} maxLength={2} placeholder="IT"
                  onChange={event => {
                    const country_code = event.target.value.toUpperCase().replace(/[^A-Z]/g, "");
                    setNewPrice(p => ({ ...p, country_code, currency: defaultCurrency[country_code] ?? p.currency }));
                  }}/>
              </label>
              <label>Store
                <select value={newPrice.store} onChange={event => setNewPrice(p => ({ ...p, store: event.target.value as PricingStore }))}>
                  <option value="apple">Apple</option><option value="google">Google</option>
                </select>
              </label>
              <label>Piano
                <select value={newPrice.plan} onChange={event => setNewPrice(p => ({ ...p, plan: event.target.value as PricingPlan }))}>
                  {plans.map(p => <option key={p} value={p}>{p.toUpperCase()}</option>)}
                </select>
              </label>
              <label>Periodicità
                <select value={newPrice.period} onChange={event => setNewPrice(p => ({ ...p, period: event.target.value as PricingPeriod }))}>
                  <option value="monthly">Mensile</option><option value="yearly">Annuale</option>
                </select>
              </label>
              <label>Valuta
                <select value={newPrice.currency} onChange={event => setNewPrice(p => ({ ...p, currency: event.target.value }))}>
                  {currencies.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </label>
              <label>Prezzo
                <input value={newPrice.amountText} inputMode="decimal" placeholder="4.59"
                  onChange={event => setNewPrice(p => ({ ...p, amountText: event.target.value }))}/>
              </label>
              <button className="primary-button" type="button" disabled={!ready || !!busy}
                onClick={() => void addPrice()}>Aggiungi con TOTP</button>
            </div>
          </section>
        </>
      )}

      <section className="panel">
        <h2>Ultime modifiche</h2>
        <p className="muted">Audit amministrativo: chi ha modificato cosa e quando. I codici TOTP non vengono mai registrati.</p>
        <div className="pricing-scroll">
          <table className="pricing-table">
            <thead><tr><th>Data</th><th>Amministratore</th><th>Tipo</th><th>Elemento</th></tr></thead>
            <tbody>
              {initial.audit.map(entry => (
                <tr key={entry.id}>
                  <td>{new Date(entry.changed_at).toLocaleString("it-IT")}</td>
                  <td><code>{entry.admin_id.slice(0, 8)}…</code></td>
                  <td>{entry.entity_type}</td><td>{entry.entity_key}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {initial.audit.length === 0 && <p className="muted">Nessuna modifica registrata.</p>}
      </section>
    </>
  );
}
