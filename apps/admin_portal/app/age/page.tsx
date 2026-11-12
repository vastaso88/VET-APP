import { AdminShell } from "../../components/admin-shell";
import { getClosedByAgeAccounts } from "../../lib/admin-api";
import {
  correctClosedAccountDate,
  eraseClosedAccount,
  markCorrectionRequested,
} from "./actions";

function date(value: string): string {
  return new Intl.DateTimeFormat("it-IT", { dateStyle: "short", timeStyle: "short" }).format(
    new Date(value),
  );
}

export default async function ClosedByAgePage() {
  const accounts = await getClosedByAgeAccounts();
  const due = accounts.filter((item) => item.past_deadline && !item.correction_requested);

  return (
    <AdminShell title="Accounts closed by age" eyebrow="Trust & safety">
      <div className="metric-grid">
        <article className="metric-card">
          <span>Closed accounts</span>
          <strong>{accounts.length}</strong>
          <small>declared an age under 14</small>
        </article>
        <article className="metric-card">
          <span>Past 30 days</span>
          <strong>{due.length}</strong>
          <small>to erase by hand</small>
        </article>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Right to erasure</p>
            <h2>Closed accounts, oldest first</h2>
          </div>
        </div>
        <p className="muted">
          Nothing is erased automatically. We erase without delay, and in any case within 30 days
          of finding out or of being asked. An account is only named by its reference: no id, no
          date of birth, and the e-mail only as a hint to recognise who wrote to support. Erasing
          uses the same eraser as the person&apos;s own deletion and shows only numbers.
        </p>
        <div className="data-table">
          <div className="table-row table-head">
            <span>Closed</span><span>Days</span><span>E-mail hint</span><span>Reference</span><span>Correction</span><span>Actions</span>
          </div>
          {accounts.length ? accounts.map((item) => (
            <div className="table-row" key={item.ref}>
              <span>{date(item.closed_at)}</span>
              <span>{item.days_closed}{item.past_deadline ? " (past 30)" : ""}</span>
              <span>{item.email_hint ?? "—"}</span>
              <span><code>{item.ref.slice(0, 8)}…</code></span>
              <span>
                <form action={markCorrectionRequested}>
                  <input type="hidden" name="ref" value={item.ref} />
                  <input type="hidden" name="requested" value={item.correction_requested ? "false" : "true"} />
                  <button className="ghost-button" type="submit">
                    {item.correction_requested ? "Requested: clear" : "Mark as requested"}
                  </button>
                </form>
              </span>
              <span>
                <form action={correctClosedAccountDate} className="moderation-action-form">
                  <input type="hidden" name="ref" value={item.ref} />
                  <label>
                    Correct date of birth
                    <input type="date" name="birth_date" required />
                  </label>
                  <button className="ghost-button" type="submit">Correct</button>
                </form>
                <form action={eraseClosedAccount} className="moderation-action-form">
                  <input type="hidden" name="ref" value={item.ref} />
                  <label>
                    <input type="checkbox" name="checked" required disabled={item.correction_requested} />
                    {" "}I checked this account
                  </label>
                  <button className="danger-button" type="submit" disabled={item.correction_requested}>
                    Erase account and data
                  </button>
                </form>
              </span>
            </div>
          )) : <div className="table-empty">No closed accounts.</div>}
        </div>
      </section>
    </AdminShell>
  );
}
