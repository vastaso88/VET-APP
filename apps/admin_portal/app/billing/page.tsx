import { AdminShell } from "../../components/admin-shell";
import { getBillingOverview, getBillingUser, type BillingUser } from "../../lib/admin-api";

function date(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", { dateStyle: "short", timeStyle: "short" }).format(
    new Date(value),
  );
}

function counts(values: Record<string, number>): string {
  const entries = Object.entries(values);
  return entries.length ? entries.map(([key, n]) => `${key}: ${n}`).join(" · ") : "—";
}

export default async function BillingPage({
  searchParams,
}: {
  searchParams: Promise<{ owner?: string }>;
}) {
  const { owner } = await searchParams;
  const overview = await getBillingOverview();
  const ownerId = owner?.trim().slice(0, 100);
  let user: BillingUser | null = null;
  let userError: string | null = null;
  if (ownerId) {
    try {
      user = await getBillingUser(ownerId);
    } catch {
      userError = "Could not load this account.";
    }
  }

  return (
    <AdminShell title="Subscriptions" eyebrow="Billing">
      <div className="metric-grid">
        <article className="metric-card">
          <span>Active subscriptions</span>
          <strong>{overview.active_subscriptions}</strong>
          <small>{counts(overview.active_by_plan)}</small>
        </article>
        <article className="metric-card">
          <span>By store</span>
          <strong>{Object.keys(overview.active_by_store).length}</strong>
          <small>{counts(overview.active_by_store)}</small>
        </article>
        <article className="metric-card">
          <span>Active trials</span>
          <strong>{overview.trials_active}</strong>
          <small>{overview.trials_ending_7d} ending in 7 days</small>
        </article>
        <article className="metric-card">
          <span>Expiring in 7 days</span>
          <strong>{overview.expiring_7d}</strong>
          <small>{overview.not_renewing} with renewal off</small>
        </article>
        <article className="metric-card">
          <span>Trial over, no plan</span>
          <strong>{overview.trials_expired_without_plan}</strong>
          <small>paywall</small>
        </article>
        <article className="metric-card">
          <span>Anomalies</span>
          <strong>{overview.anomalies}</strong>
          <small>claims by other accounts, store rejections</small>
        </article>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Estimate — not revenue</p>
            <h2>€ {overview.revenue.monthly_recurring_eur_estimate.toFixed(2)} / month (gross list)</h2>
          </div>
        </div>
        <p className="muted">{overview.revenue.note}</p>
        <p className="muted">
          Reconciled proceeds:{" "}
          {overview.revenue.reconciled_eur === null
            ? "not available (import the App Store Connect / Play Console financial reports)"
            : `€ ${overview.revenue.reconciled_eur.toFixed(2)}`}
        </p>
        <p className="muted">States: {counts(overview.states)}</p>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">User card</p>
            <h2>Subscription of one account</h2>
          </div>
        </div>
        <form method="get">
          <input name="owner" defaultValue={ownerId ?? ""} placeholder="Account id" maxLength={100} />
          <button type="submit">Show</button>
        </form>
        {userError ? <p className="muted">{userError}</p> : null}
        {user ? (
          <>
            <p className="muted">
              Active plan: <strong>{user.plan ?? "none"}</strong> · Trial ends: {date(user.trial_ends_at)}
            </p>
            <div className="data-table">
              <div className="table-row table-head">
                <span>Store</span><span>Plan</span><span>State</span><span>Expires / renews</span><span>Last check</span><span>Anomaly</span>
              </div>
              {user.subscriptions.map((item) => (
                <div className="table-row" key={`${item.store}-${item.product_id}-${item.last_verified_at}`}>
                  <span>{item.store} ({item.environment})</span>
                  <span>{item.plan} · {item.period}</span>
                  <span>{item.state}{item.grants_access ? " ✓" : ""}</span>
                  <span>
                    {date(item.expires_at)} {item.auto_renew ? "· renews" : "· renewal off"}
                    {item.revoked_at ? ` · revoked ${date(item.revoked_at)}` : ""}
                  </span>
                  <span>
                    {date(item.last_verified_at)}
                    {item.verification_error_at ? ` · store error since ${date(item.verification_error_at)}` : ""}
                  </span>
                  <span>{item.anomaly ?? "—"}</span>
                </div>
              ))}
              {user.subscriptions.length === 0 ? (
                <div className="table-row"><span>No store subscription</span></div>
              ) : null}
            </div>
          </>
        ) : null}
      </section>
    </AdminShell>
  );
}
