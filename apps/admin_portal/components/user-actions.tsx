"use client";

import { useState } from "react";
import Link from "next/link";
import { confirmAction, prepareAction } from "../app/users/actions";
import type {
  UserActionInput,
  UserActionPreview,
  UserActionResult,
  UserCase,
} from "../lib/admin-api";
import { actionLabels } from "../lib/user-format";

export function UserActions({
  ownerIds = [],
  cases = [],
  filter,
  allResults = false,
}: {
  ownerIds?: string[];
  cases?: UserCase[];
  filter?: { q: string; country: string };
  allResults?: boolean;
}) {
  const [preview, setPreview] = useState<UserActionPreview | null>(null);
  const [results, setResults] = useState<UserActionResult[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [action, setAction] = useState<UserActionInput["action"]>(
    "restrict_marketplace",
  );
  const selected = ownerIds.length + cases.length;
  async function prepare(formData: FormData) {
    setError("");
    setResults(null);
    setBusy(true);
    try {
      setPreview(
        await prepareAction({
          action,
          reason: String(formData.get("reason")) as UserActionInput["reason"],
          note: String(formData.get("note") ?? ""),
          duration_days: Number(formData.get("days") ?? 7),
          owner_ids: allResults ? [] : ownerIds,
          cases: allResults ? [] : cases,
          all_results: allResults,
          ...filter,
        }),
      );
    } catch {
      setError(
        "Anteprima non disponibile. Verifica selezione, motivazione e massimo 100 account. Gli account del team sono protetti.",
      );
    } finally {
      setBusy(false);
    }
  }
  async function confirm() {
    if (!preview) return;
    setBusy(true);
    setError("");
    try {
      setResults((await confirmAction(preview.token)).results);
      setPreview(null);
    } catch {
      setError(
        "Operazione non completata o anteprima scaduta. Prepara una nuova anteprima; gli esiti già applicati restano nello storico.",
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="user-actions">
      <h3>
        Azioni{" "}
        {allResults
          ? "su tutti i risultati filtrati"
          : `su ${selected} account ${selected === 1 ? "selezionato" : "selezionati"}`}
      </h3>
      <p className="muted">
        La sospensione riguarda soltanto il Mercatino. La revoca dispositivi
        viene rilevata alla prossima apertura dell’app: non chiude
        immediatamente tutte le sessioni.
      </p>
      {!preview && (
        <form action={prepare} className="support-action-form">
          <label>
            Azione
            <select
              value={action}
              onChange={(event) =>
                setAction(event.target.value as UserActionInput["action"])
              }
            >
              {Object.entries(actionLabels).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
          <label>
            Motivo
            <select name="reason" defaultValue="other">
              <option value="other">Altro / assistenza</option>
              <option value="spam">Spam</option>
              <option value="scam">Truffa</option>
              <option value="harassment">Molestie</option>
              <option value="prohibited_items">Articoli vietati</option>
            </select>
          </label>
          {action === "restrict_marketplace" && (
            <label>
              Durata in giorni
              <input
                type="number"
                name="days"
                min={1}
                max={90}
                defaultValue={7}
                required
              />
            </label>
          )}
          <label className="support-note">
            Motivazione interna
            <textarea
              name="note"
              minLength={3}
              maxLength={1000}
              required
              placeholder="Perché è necessario questo intervento"
            />
          </label>
          <button
            className="ghost-button"
            disabled={busy || (!allResults && selected === 0)}
            type="submit"
          >
            {busy ? "Preparazione…" : "Prepara anteprima"}
          </button>
        </form>
      )}
      {preview && (
        <section className="action-preview" aria-label="Anteprima intervento">
          <h4>
            {actionLabels[preview.action]} · {preview.users.length} account
          </h4>
          <p>{preview.note}</p>
          {preview.action === "restrict_marketplace" && (
            <p>
              Durata: {preview.duration_days} giorni. Una sospensione già attiva
              non viene estesa.
            </p>
          )}
          <p className="muted">
            Questa selezione è fissata per dieci minuti. Controlla gli account
            prima di confermare.
          </p>
          <ul>
            {preview.users.map((user) => (
              <li key={user.id}>
                <Link href={`/users/${encodeURIComponent(user.id)}`}>
                  {user.email ?? user.id}
                </Link>
                {user.case && <span> · caso {user.case.id}</span>}
              </li>
            ))}
          </ul>
          <button
            className="danger-button"
            type="button"
            disabled={busy}
            onClick={confirm}
          >
            {busy
              ? "Applicazione…"
              : `Conferma su ${preview.users.length} account`}
          </button>{" "}
          <button
            className="ghost-button"
            type="button"
            disabled={busy}
            onClick={() => setPreview(null)}
          >
            Annulla
          </button>
        </section>
      )}
      {error && <p role="alert">{error}</p>}
      {results && (
        <div role="status">
          <h4>Esito per account</h4>
          <ul>
            {results.map((result) => (
              <li key={result.id}>
                <Link href={`/users/${encodeURIComponent(result.id)}`}>
                  {result.id}
                </Link>
                :{" "}
                {result.status === "applied"
                  ? result.changed
                    ? "Applicato"
                    : "Nessuna modifica necessaria"
                  : result.status === "already_applied"
                    ? "Già applicato"
                    : result.status === "conflict"
                      ? "Stato cambiato: prepara una nuova anteprima"
                      : "Non applicato: verifica e riprova"}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
