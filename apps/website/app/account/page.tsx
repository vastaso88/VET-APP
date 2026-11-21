import type { Metadata } from "next";
import Link from "next/link";
import { api, BillingStatus } from "../../lib/api";
import { logout } from "../actions";
export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  title: "Area personale",
  robots: { index: false, follow: false },
};
export default async function Account() {
  const me = await api("/auth/me");
  if (!me.ok) throw new Error("Account unavailable");
  const user = await me.json();
  const response = await api("/subscription/status");
  const status: BillingStatus | null = response.ok
    ? await response.json()
    : null;
  return (
    <section className="account">
      <div className="account-heading">
        <div>
          <p className="eyebrow">AREA PERSONALE</p>
          <h1>Ciao, sei a casa.</h1>
          <p>{user.email}</p>
        </div>
        <form action={logout}>
          <button className="secondary">Esci</button>
        </form>
      </div>
      <div className="status">
        <p className="eyebrow">IL TUO ACCESSO</p>
        <h2>
          {!status
            ? "Stato non disponibile"
            : status.subscription.plan
              ? `Piano ${status.subscription.plan}`
              : status.has_access
                ? "Prova in corso"
                : "Prova terminata"}
        </h2>
        <p>
          {!status
            ? "Non riusciamo a verificare lo stato. Riprova tra poco."
            : status.has_access
              ? "Il tuo account ha accesso all’app Quokka."
              : "Il tuo account non ha un piano attivo."}
        </p>
        {status && (
          <p>
            Fine della prova:{" "}
            {new Intl.DateTimeFormat("it-IT", {
              dateStyle: "long",
              timeZone: "Europe/Rome",
            }).format(new Date(status.subscription.trial_ends_at))}
          </p>
        )}
        <Link className="button" href="/account/billing">
          Abbonamento e pagamenti ↗
        </Link>
      </div>
      <div className="account-services">
        <article>
          <span className="number">01 / ABBONAMENTO</span>
          <h2>Il piano che fa per voi.</h2>
          <p>
            Consulta i piani, verifica il rinnovo e accedi alla gestione Stripe
            di pagamenti e fatture.
          </p>
          <Link href="/account/billing">Apri abbonamento →</Link>
        </article>
        <article>
          <span className="number">02 / IL TUO ACCOUNT</span>
          <h2>Le stesse credenziali.</h2>
          <p>
            Usa questo account anche nell’app. Puoi modificare il profilo,
            recuperare la password ed esportare o eliminare i dati dalle
            impostazioni dell’app.
          </p>
          <Link href="/legal">Privacy e condizioni →</Link>
        </article>
      </div>
    </section>
  );
}
