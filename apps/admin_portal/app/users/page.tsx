import Link from "next/link";
import { AdminShell } from "../../components/admin-shell";
import { UsersTable } from "../../components/users-table";
import { getAdminUsers } from "../../lib/admin-api";
import { countryName } from "../../lib/user-format";

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string; country?: string }>;
}) {
  const params = await searchParams;
  const q = (params.q ?? "").slice(0, 200);
  const country = /^(unknown|[A-Z]{2})$/.test(params.country ?? "")
    ? params.country!
    : "";
  const parsedPage = Number(params.page);
  const page =
    Number.isInteger(parsedPage) && parsedPage > 0
      ? Math.min(parsedPage, 2000)
      : 1;
  const data = await getAdminUsers(q, page, country);
  const pageUrl = (target: number) =>
    `/users?${new URLSearchParams({ q, country, page: String(target) })}`;
  return (
    <AdminShell
      title="Users"
      eyebrow="Account e assistenza"
      className="users-shell"
    >
      <section className="panel users-panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Controllo utenti</p>
            <h2>Account, utilizzo e moderazione</h2>
          </div>
          <Link className="ghost-button" href="/users/closed-by-age">
            Account chiusi per età →
          </Link>
        </div>
        <form className="job-filters users-search" action="/users">
          <label>
            Cerca per email o ID
            <input
              name="q"
              type="search"
              maxLength={200}
              defaultValue={q}
              placeholder="Email o ID utente"
            />
          </label>
          <label>
            Nazione
            <select name="country" defaultValue={country}>
              <option value="">Tutte le nazioni</option>
              {data &&
                Object.entries(data.countries).map(([code, count]) => (
                  <option key={code} value={code}>
                    {countryName(code)} · {count}
                  </option>
                ))}
              {country && !data?.countries[country] && (
                <option value={country}>{countryName(country)} · 0</option>
              )}
            </select>
          </label>
          <button className="ghost-button" type="submit">
            Filtra
          </button>
          {(q || country) && (
            <Link className="ghost-button" href="/users">
              Azzera filtri
            </Link>
          )}
        </form>
        <p className="muted">
          La nazione proviene dalla residenza salvata, mai dalla lingua
          dell’app. I conteggi per nazione si riferiscono alla ricerca su tutti
          gli account, prima della paginazione. Apri un utente per metriche,
          accessi, casi di moderazione e interventi.
        </p>
      </section>
      {!data ? (
        <section className="panel" role="alert">
          <h2>Dati utenti non disponibili</h2>
          <p className="muted">
            Verifica il backend e la migrazione dati del portale, poi riprova.
          </p>
        </section>
      ) : (
        <>
          <div className="metric-grid users-metrics">
            <article className="metric-card">
              <span>Account nei risultati</span>
              <strong>{data.total}</strong>
              <small>Filtri applicati a tutti gli account</small>
            </article>
            <article className="metric-card">
              <span>Modalità abbonamenti</span>
              <strong>
                {data.test_plan
                  ? `Test ${data.test_plan.toUpperCase()}`
                  : "Standard"}
              </strong>
              <small>Il piano assegnato non prova un pagamento</small>
            </article>
            <article className="metric-card">
              <span>Incassi registrati</span>
              <strong>Non disponibili</strong>
              <small>Storico transazioni non collegato</small>
            </article>
          </div>
          <section className="panel users-panel">
            <div className="panel-heading">
              <h2>Utenti · più recenti prima</h2>
              <span className="muted">
                {data.total ? (data.page - 1) * data.page_size + 1 : 0}–
                {Math.min(data.page * data.page_size, data.total)} di{" "}
                {data.total}
              </span>
            </div>
            <UsersTable
              key={`${q}:${country}:${data.page}`}
              users={data.users}
              q={q}
              country={country}
            />
            <nav className="users-pagination" aria-label="Pagine utenti">
              {data.page > 1 && (
                <Link className="ghost-button" href={pageUrl(data.page - 1)}>
                  Precedenti
                </Link>
              )}
              <span>
                Pagina {data.page} di{" "}
                {Math.max(1, Math.ceil(data.total / data.page_size))}
              </span>
              {data.page * data.page_size < data.total && (
                <Link className="ghost-button" href={pageUrl(data.page + 1)}>
                  Successivi
                </Link>
              )}
            </nav>
          </section>
        </>
      )}
    </AdminShell>
  );
}
