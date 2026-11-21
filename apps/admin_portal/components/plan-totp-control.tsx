"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  beginPlanTotpSetup,
  changePlanWithTotp,
  completePlanTotpSetup,
} from "../app/users/actions";

type Setup = { factorId: string; qrDataUrl: string; secret: string };
type Plan = "none" | "plus" | "pro" | "ultra";

export function PlanTotpControl({
  ownerId,
  storedPlan,
  initialTotpEnabled,
}: {
  ownerId: string;
  storedPlan: string | null;
  initialTotpEnabled: boolean | null;
}) {
  const router = useRouter();
  const [enabled, setEnabled] = useState(initialTotpEnabled);
  const [setup, setSetup] = useState<Setup | null>(null);
  const [plan, setPlan] = useState<Plan>(
    storedPlan === "plus" || storedPlan === "pro" || storedPlan === "ultra" ? storedPlan : "none",
  );
  const [code, setCode] = useState("");
  const [setupCode, setSetupCode] = useState("");
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState("");

  async function startSetup() {
    setPending(true);
    setMessage("");
    try {
      const response = await beginPlanTotpSetup();
      if (!response.ok) {
        setMessage(response.error);
      } else if (response.result.status === "already_enabled") {
        setEnabled(true);
        setMessage("TOTP già configurato. Inserisci il codice per modificare il piano.");
      } else {
        const { factorId, qrDataUrl, secret } = response.result;
        setSetup({ factorId, qrDataUrl, secret });
      }
    } catch {
      setMessage("Impossibile avviare la configurazione TOTP.");
    } finally {
      setPending(false);
    }
  }

  async function confirmSetup() {
    if (!setup || !/^\d{6}$/.test(setupCode)) {
      setMessage("Inserisci le 6 cifre generate dall'app.");
      return;
    }
    setPending(true);
    setMessage("");
    try {
      const result = await completePlanTotpSetup(setup.factorId, setupCode);
      if (!result.ok) {
        setMessage(result.error);
      } else {
        setSetup(null);
        setSetupCode("");
        setEnabled(true);
        setMessage("TOTP attivato. Puoi modificare il piano con un nuovo codice.");
        router.refresh();
      }
    } catch {
      setMessage("Verifica TOTP non riuscita.");
    } finally {
      setPending(false);
    }
  }

  async function submitPlan() {
    if (!/^\d{6}$/.test(code)) {
      setMessage("Inserisci il codice TOTP di 6 cifre.");
      return;
    }
    setPending(true);
    setMessage("");
    try {
      const result = await changePlanWithTotp(ownerId, plan, code);
      setCode("");
      if (!result.ok) {
        setMessage(result.error);
      } else {
        setMessage("Piano aggiornato e operazione registrata.");
        router.refresh();
      }
    } catch {
      setCode("");
      setMessage("Cambio piano non riuscito.");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="job-filters users-search" aria-label="Modifica piano protetta da TOTP">
      <p className="muted">
        Operazione sensibile: è obbligatorio il codice temporaneo di un'app Authenticator
        per <strong>ogni modifica</strong>. Il codice non viene conservato.
      </p>
      {enabled === false || enabled === null ? (
        <div>
          <p className="muted">
            {enabled === null
              ? "Impossibile verificare lo stato del secondo fattore."
              : "Secondo fattore TOTP non ancora attivato per questo amministratore."}
          </p>
          {!setup ? (
            <button className="primary-button" type="button" disabled={pending} onClick={() => void startSetup()}>
              Configura Authenticator
            </button>
          ) : (
            <div>
              <p>Scansiona il QR con Google Authenticator, 1Password o un'app TOTP compatibile.</p>
              {/* Supabase Auth emits this QR SVG; only the authenticated admin can request it. */}
              <img src={setup.qrDataUrl} alt="QR per configurare il codice TOTP" width={200} height={200} />
              <p>Oppure inserisci manualmente la chiave: <code>{setup.secret}</code></p>
              <p className="muted">Non condividere la chiave. Aggiungi un secondo dispositivo di recupero.</p>
              <label>
                Codice di attivazione (6 cifre)
                <input
                  value={setupCode}
                  onChange={(event) => setSetupCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  maxLength={6}
                  placeholder="000000"
                />
              </label>
              <button className="primary-button" type="button" disabled={pending}
                onClick={() => void confirmSetup()}>Attiva TOTP</button>
            </div>
          )}
        </div>
      ) : (
        <form onSubmit={(event) => { event.preventDefault(); void submitPlan(); }}>
          <label>
            Modifica piano assegnato
            <select value={plan} onChange={(event) => setPlan(event.target.value as Plan)} disabled={pending}>
              <option value="none">Nessun piano (prova / scaduto)</option>
              <option value="plus">Plus</option>
              <option value="pro">Pro</option>
              <option value="ultra">Ultra</option>
            </select>
          </label>
          <label>
            Codice Authenticator
            <input
              value={code}
              onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              placeholder="000000"
              required
            />
          </label>
          <button type="submit" className="primary-button" disabled={pending || code.length !== 6}>
            {pending ? "Verifica in corso…" : "Verifica TOTP e salva piano"}
          </button>
        </form>
      )}
      <span className="muted">Le modifiche sono registrate nell'audit. Non costituiscono un pagamento.</span>
      {message && <p role="status">{message}</p>}
    </div>
  );
}
