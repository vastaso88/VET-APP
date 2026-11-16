import Link from "next/link";

import { AdminShell } from "../../components/admin-shell";
import { getAdminUsers, type UserAccount } from "../../lib/admin-api";

const accessLabels: Record<UserAccount["access"], string> = {
  developer: "Sviluppatore · senza limiti",
  test: "Periodo di test",
  not_started: "Prova non avviata",
  plan: "Piano assegnato",
  trial: "Prova attiva",
  expired: "Prova scaduta",
};

function date(value: string | null): string {
  if (!value) return "—";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short", timeStyle: "short", timeZone: "Europe/Rome",
  }).format(parsed);
}

export default async function UsersPage({ searchParams }: {
  searchParams: Promise<{ q?: string; page?: string }>;
}) {
  const params = await searchParams;
  const q = (params.q ?? "").slice(0, 200);
  const parsedPage = Number(params.page);
  const page = Number.isInteger(parsedPage) && parsedPage > 0
    ? Math.min(parsedPage, 2000) : 1;
  const data = await getAdminUsers(q, page);
  const pageUrl = (target: number) => `/users?${new URLSearchParams({ q, page: String(target) })}`;

  return (
    <AdminShell title="Users" eyebrow="Account e abbonamenti">
      <section className="panel users-panel">
        <div className="panel-heading">
          <div><p className="eyebrow">Controllo utenti</p><h2>Iscrizione, accesso e piano</h2></div>
          <Link className="ghost-button" href={pageUrl(page)}>Aggiorna</Link>
        </div>
        <form className="job-filters" action="/users">
          <label>Cerca per email o ID
            <input name="q" type="search" maxLength={200} defaultValue={q} placeholder="Email o ID utente" />
          </label>
          <button className="ghost-button" type="submit">Cerca</button>
          {q && <Link className="ghost-button" href="/users">Azzera ricerca</Link>}
        </form>
        <p className="muted">La data di iscrizione proviene dall’account; l’ultimo accesso indica
          l’ultimo login, non l’ultima attività. Date e orari sono espressi nel fuso di Roma.</p>
      </section>

      {!data ? (
        <section className="panel" role="alert">
          <h2>Dati utenti non disponibili</h2>
          <p className="muted">Impossibile leggere gli account o i piani. Riprova dopo aver verificato
            che il backend sia aggiornato e disponibile.</p>
        </section>
      ) : <>
        <div className="metric-grid users-metrics">
          <article className="metric-card"><span>{q ? "Risultati ricerca" : "Account registrati"}</span>
            <strong>{data.total}</strong><small>Inclusi gli account senza profilo o piano</small></article>
          <article className="metric-card"><span>Modalità abbonamenti</span>
            <strong>{data.test_plan ? `Test ${data.test_plan.toUpperCase()}` : "Standard"}</strong>
            <small>{data.test_plan ? "Piano di test applicato a tutti gli account" : "Prova o piano assegnato per account"}</small></article>
          <article className="metric-card"><span>Incassi registrati</span>
            <strong>Non disponibili</strong><small>Storico pagamenti non collegato</small></article>
        </div>
        <section className="panel users-panel">
          <div className="panel-heading"><h2>Utenti · più recenti prima</h2>
            <span className="muted">{data.total ? (data.page - 1) * data.page_size + 1 : 0}–{Math.min(data.page * data.page_size, data.total)} di {data.total}</span></div>
          <p className="muted">Un piano assegnato non prova un pagamento. Totale pagato, ultimo pagamento,
            fatture e rimborsi richiedono uno storico delle transazioni.
            {data.test_plan ? " Durante il periodo di test il piano effettivo può differire da quello salvato." : ""}</p>
          <div className="users-table-scroll">
            <table className="users-table">
              <caption className="sr-only">Account, date di iscrizione e accesso, piani e pagamenti</caption>
              <thead><tr>{["Utente", "Iscritto dal", "Ultimo accesso", "Account", "Piano e accesso", "Fine prova", "Totale pagato", "Ultimo pagamento"].map((label) => <th scope="col" key={label}>{label}</th>)}</tr></thead>
              <tbody>{data.users.map((user) => <tr key={user.id}>
                <td><strong>{user.email ?? "Senza email"}</strong><small>{user.id}</small></td>
                <td>{date(user.created_at)}</td>
                <td>{date(user.last_sign_in_at)}</td>
                <td>{user.banned_until ? <>Sospeso fino al {date(user.banned_until)}</> : "Non sospeso"}
                  <small>{user.email_verified ? "Email verificata" : "Email non verificata"}</small></td>
                <td><strong>{user.effective_plan?.toUpperCase() ?? "Nessun piano"}</strong>
                  <small>{accessLabels[user.access]}</small>
                  {data.test_plan && <small>Salvato: {user.stored_plan?.toUpperCase() ?? "nessuno"}</small>}</td>
                <td>{date(user.trial_ends_at)}{data.test_plan && <small>Non applicata durante il test</small>}</td>
                <td>Non disponibile</td><td>Non disponibile</td>
              </tr>)}</tbody>
            </table>
            {!data.users.length && <p className="table-empty">{q ? "Nessun utente corrisponde alla ricerca." : "Nessun account registrato."}</p>}
          </div>
          <nav className="users-pagination" aria-label="Pagine utenti">
            {data.page > 1 && <Link className="ghost-button" href={pageUrl(data.page - 1)}>Precedenti</Link>}
            <span>Pagina {data.page} di {Math.max(1, Math.ceil(data.total / data.page_size))}</span>
            {data.page * data.page_size < data.total && <Link className="ghost-button" href={pageUrl(data.page + 1)}>Successivi</Link>}
          </nav>
        </section>
      </>}
    </AdminShell>
  );
}
