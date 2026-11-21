import Link from "next/link";
import { notFound } from "next/navigation";
import { AdminShell } from "../../../components/admin-shell";
import { UserActions } from "../../../components/user-actions";
import { UserTimeline } from "../../../components/user-timeline";
import { getUserDetail } from "../../../lib/admin-api";
import { accessLabels, countryName, userDate } from "../../../lib/user-format";

export default async function UserPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const data = await getUserDetail(id);
  if (!data) notFound();
  const { user, usage } = data;
  const location = data.location?.[0];
  const restriction = data.restriction?.[0];
  const restricted =
    restriction &&
    !restriction.lifted_at &&
    (!restriction.expires_at ||
      new Date(restriction.expires_at).getTime() > Date.now());
  const metrics = usage
    ? [
        ["Animali", usage.pets],
        ["Conversazioni", usage.conversations],
        ["Messaggi inviati", usage.messages],
        ["Annunci", usage.listings],
        ["Giorni con uso quote · 7 giorni", usage.quota_days_7d],
        ["Giorni con uso quote · 30 giorni", usage.quota_days_30d],
      ]
    : [];
  return (
    <AdminShell
      title={user.email ?? "Dettaglio utente"}
      eyebrow="Users / Dettaglio"
      className="users-shell"
    >
      <nav className="users-selection" aria-label="Sezioni utente">
        <Link className="table-action-link" href="/users">
          ← Users
        </Link>
        <a href="#account">Account</a>
        <a href="#usage">Utilizzo</a>
        <a href="#moderation">Moderazione</a>
        <a href="#history">Storico</a>
        <a href="#actions">Azioni</a>
      </nav>
      {data.unavailable.length > 0 && (
        <section className="panel users-panel" role="alert">
          <h2>Alcune sezioni non sono disponibili</h2>
          <p className="muted">
            {data.unavailable.join(", ")}. Verifica migrazione e servizi; nessun
            valore mancante viene interpretato come zero.
          </p>
        </section>
      )}
      <section id="account" className="panel users-panel">
        <h2>Account e piano</h2>
        <dl className="user-facts">
          <div>
            <dt>ID</dt>
            <dd>{user.id}</dd>
          </div>
          <div>
            <dt>Iscritto dal</dt>
            <dd>{userDate(user.created_at)}</dd>
          </div>
          <div>
            <dt>Ultimo login</dt>
            <dd>{userDate(user.last_sign_in_at)}</dd>
          </div>
          <div>
            <dt>Email</dt>
            <dd>{user.email_verified ? "Verificata" : "Non verificata"}</dd>
          </div>
          <div>
            <dt>Piano effettivo</dt>
            <dd>
              {user.effective_plan?.toUpperCase() ?? "Nessuno"} ·{" "}
              {accessLabels[user.access]}
            </dd>
          </div>
          <div>
            <dt>Piano salvato</dt>
            <dd>{user.stored_plan?.toUpperCase() ?? "Nessuno"}</dd>
          </div>
          <div>
            <dt>Fine prova</dt>
            <dd>{userDate(user.trial_ends_at)}</dd>
          </div>
          <div>
            <dt>Pagamenti</dt>
            <dd>Storico transazioni non collegato</dd>
          </div>
          <div>
            <dt>Nazione della residenza</dt>
            <dd>{countryName(location?.home_country_code)}</dd>
          </div>
          <div>
            <dt>Città</dt>
            <dd>{location?.home_city ?? "Non disponibile"}</dd>
          </div>
          <div>
            <dt>Residenza aggiornata</dt>
            <dd>{userDate(location?.home_saved_at)}</dd>
          </div>
          <div>
            <dt>Ultima posizione disponibile</dt>
            <dd>
              {userDate(location?.current_captured_at)} ·{" "}
              {location?.current_source ?? "Fonte non disponibile"}
            </dd>
          </div>
        </dl>
        <p className="muted">
          La residenza è quella salvata dall’utente, non una verifica di
          domicilio. Non vengono mostrati indirizzo esatto, coordinate o
          percorsi.
        </p>
      </section>
      <section id="usage" className="panel users-panel">
        <h2>Utilizzo</h2>
        <p className="muted">
          I totali riguardano i dati ancora conservati. I giorni attivi indicano
          giorni con consumo di quote chat, foto, dettatura o riepiloghi, non
          tutte le aperture dell’app.
        </p>
        {usage ? (
          <>
            <div className="metric-grid users-metrics">
              {metrics.map(([label, value]) => (
                <article className="metric-card" key={label}>
                  <span>{label}</span>
                  <strong>{value}</strong>
                </article>
              ))}
            </div>
            <p className="muted">
              Ultima attività registrata da un dispositivo:{" "}
              {userDate(usage.last_device_activity_at)}. Questo dato non
              coincide necessariamente con l’ultimo login.
            </p>
            <div className="users-table-scroll">
              <table className="users-table user-compact-table">
                <caption>
                  Quote consumate negli ultimi 30 giorni · date UTC
                </caption>
                <thead>
                  <tr>
                    {[
                      "Giorno",
                      "Messaggi",
                      "Foto",
                      "Dettatura",
                      "Riepiloghi",
                      "Sonnet",
                      "Continuazioni",
                    ].map((label) => (
                      <th scope="col" key={label}>
                        {label}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {usage.daily.map((day) => (
                    <tr key={day.day}>
                      <td>{day.day}</td>
                      <td>{day.messages}</td>
                      <td>{day.vision}</td>
                      <td>{day.dictation}</td>
                      <td>{day.summary}</td>
                      <td>{day.sonnet}</td>
                      <td>{day.followup}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {!usage.daily.length && (
                <p className="muted">Nessun consumo registrato nel periodo.</p>
              )}
            </div>
          </>
        ) : (
          <p className="muted">Metriche non disponibili.</p>
        )}
      </section>
      <section className="panel users-panel">
        <h2>Dispositivi e accessi</h2>
        <p className="muted">
          Fino a 100 dispositivi. Il registro dei login riusciti raccoglie gli
          eventi dall’attivazione della migrazione e li conserva per 90 giorni;
          non ricostruisce accessi precedenti né tentativi falliti. L’ultimo
          login dell’account resta disponibile sopra. Nessun IP o token viene
          mostrato.
        </p>
        <div className="users-table-scroll">
          <table className="users-table user-compact-table">
            <caption>Dispositivi registrati nell’app</caption>
            <thead>
              <tr>
                <th scope="col">Riferimento</th>
                <th scope="col">Primo utilizzo</th>
                <th scope="col">Ultima attività</th>
                <th scope="col">Revoca</th>
              </tr>
            </thead>
            <tbody>
              {data.devices?.map((device) => (
                <tr key={device.device_id}>
                  <td>{device.device_id}</td>
                  <td>{userDate(device.first_seen_at)}</td>
                  <td>{userDate(device.last_seen_at)}</td>
                  <td>{userDate(device.revoked_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {data.devices?.length === 0 && (
          <p className="muted">Nessun dispositivo registrato.</p>
        )}
      </section>
      <section id="moderation" className="panel users-panel">
        <h2>Moderazione</h2>
        <p className="muted">
          Segnalazioni ricevute e inviate sono distinte. Una segnalazione non
          equivale a una violazione accertata e non produce penalizzazioni
          automatiche. I casi anonimi di Chat e Radar mantengono il loro
          anonimato.
        </p>
        {data.moderation ? (
          <>
            <p>
              {data.moderation.received} ricevute · {data.moderation.filed}{" "}
              inviate nei casi caricati
              {data.moderation.truncated ? " · elenco parziale" : ""}.
            </p>
            <div className="users-table-scroll">
              <table className="users-table user-compact-table">
                <caption>Casi del Mercatino collegati a questo account</caption>
                <thead>
                  <tr>
                    <th scope="col">Caso</th>
                    <th scope="col">Relazione</th>
                    <th scope="col">Motivo</th>
                    <th scope="col">Stato</th>
                  </tr>
                </thead>
                <tbody>
                  {data.moderation.events.map((event) => (
                    <tr key={`${event.queue}:${event.id}:${event.direction}`}>
                      <td>
                        <Link
                          className="table-action-link"
                          href={`/moderation/${event.queue}/${encodeURIComponent(event.id)}`}
                        >
                          {event.queue} · {event.id}
                        </Link>
                      </td>
                      <td>
                        {event.direction === "received"
                          ? "Ricevuta"
                          : "Inviata"}
                      </td>
                      <td>{event.reason}</td>
                      <td>{event.status}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        ) : (
          <p>Casi non disponibili.</p>
        )}
        <p className="muted">
          Mercatino:{" "}
          {data.restriction === null
            ? "stato non disponibile"
            : restricted
              ? `sospeso · ${restriction.reason} · scadenza ${userDate(restriction.expires_at)}`
              : "nessuna sospensione attiva"}
          .
        </p>
      </section>
      <section id="history" className="panel users-panel">
        <h2>Timeline</h2>
        <p className="muted">
          Fino a 100 login e 100 interventi recenti; gli interventi sono
          conservati per 365 giorni. Le schede dei casi mostrano lo stato
          attuale e l’ultima decisione disponibile.
        </p>
        <UserTimeline
          actions={data.actions}
          logins={data.logins}
          moderation={data.moderation}
        />
      </section>
      <section id="actions" className="panel users-panel">
        <UserActions ownerIds={[id]} />
      </section>
    </AdminShell>
  );
}
