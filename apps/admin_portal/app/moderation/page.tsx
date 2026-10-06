import { AdminShell } from "../../components/admin-shell";
import { getAdminModeration } from "../../lib/admin-api";
import { resolveChatReport } from "./actions";

function date(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function ModerationPage() {
  const moderation = await getAdminModeration();
  const openRadar = moderation.radar.filter((item) => item.status === "pending");
  const openChat = moderation.chat.filter(
    (item) => item.status === "reported" || item.status === "under_review",
  );

  return (
    <AdminShell title="Moderation" eyebrow="Trust & safety">
      <div className="metric-grid">
        <article className="metric-card">
          <span>Radar reports</span>
          <strong>{openRadar.length}</strong>
          <small>{moderation.radar.length} loaded</small>
        </article>
        <article className="metric-card">
          <span>Chat reports</span>
          <strong>{openChat.length}</strong>
          <small>{moderation.chat.length} loaded</small>
        </article>
        <article className="metric-card">
          <span>Marketplace reports</span>
          <strong>{moderation.marketplace.length}</strong>
          <small>All reports currently require review</small>
        </article>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Marketplace</p>
            <h2>Live reports</h2>
          </div>
        </div>
        <div className="data-table moderation-live-table">
          <div className="table-row table-head">
            <span>Created</span><span>Reason</span><span>Listing</span><span>Status</span><span>Reports</span>
          </div>
          {moderation.marketplace.length ? moderation.marketplace.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.created_at)}</span>
              <span>{item.reason}</span>
              <span>{item.listing?.title ?? item.listing_id}</span>
              <span>{item.listing?.status ?? "missing"}</span>
              <span>{item.listing?.report_count ?? "—"}</span>
            </div>
          )) : <div className="table-empty">No marketplace reports.</div>}
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Chat</p>
            <h2>Response reports</h2>
          </div>
        </div>
        {moderation.chat.length ? (
          <div className="stack-list">
            {moderation.chat.map((item) => (
              <article className="record-card" key={item.id}>
                <div className="record-card-head">
                  <div>
                    <strong>{item.reason}</strong>
                    <span>{item.status} · {date(item.created_at)}</span>
                  </div>
                  <code>{item.id}</code>
                </div>
                {item.details ? <p>{item.details}</p> : null}
                <details>
                  <summary>Reported answer</summary>
                  <pre className="report-answer">{item.reported_answer}</pre>
                </details>
                {(item.status === "reported" || item.status === "under_review") ? (
                  <form action={resolveChatReport} className="inline-admin-form">
                    <input type="hidden" name="report_id" value={item.id} />
                    <select
                      name="status"
                      defaultValue={item.status === "reported" ? "under_review" : item.status}
                    >
                      <option value="under_review">under_review</option>
                      <option value="resolved">resolved</option>
                      <option value="wont_fix">wont_fix</option>
                    </select>
                    <input name="resolution_note" placeholder="Resolution note" />
                    <button className="primary-button" type="submit">Save</button>
                  </form>
                ) : (
                  <p className="muted">
                    Resolved: {date(item.resolved_at)} {item.resolution_note ?? ""}
                  </p>
                )}
              </article>
            ))}
          </div>
        ) : <p className="muted">No chat response reports.</p>}
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Radar</p>
            <h2>User reports</h2>
          </div>
        </div>
        <div className="data-table radar-report-table">
          <div className="table-row table-head">
            <span>Created</span><span>Kind</span><span>Status</span><span>Place</span><span>Votes</span><span>Target</span>
          </div>
          {moderation.radar.length ? moderation.radar.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.created_at)}</span>
              <span>{item.kind}</span>
              <span>{item.status}</span>
              <span>{item.name ?? item.place_type}</span>
              <span>{item.confirmations} / {item.denials}</span>
              <span>{item.target_source ?? "new place"}</span>
            </div>
          )) : <div className="table-empty">No Radar reports.</div>}
        </div>
      </section>
    </AdminShell>
  );
}
