import Link from "next/link";
import { AdminShell } from "../components/admin-shell";
import { getAdminOverview } from "../lib/admin-api";

function formatNumber(value: number): string {
  return new Intl.NumberFormat("it-IT").format(value);
}

function formatDate(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

const speciesLabels: Record<string, string> = {
  dog: "Dogs",
  cat: "Cats",
  small_mammal: "Small mammals",
  bird: "Birds",
  reptile_amphibian: "Reptiles / amphibians",
  fish: "Fish",
  unknown: "Unknown",
};

export default async function OverviewPage() {
  const overview = await getAdminOverview();
  const metrics = [
    ["Account", formatNumber(overview.metrics.users), "Supabase Auth", "/users"],
    ["Pet", formatNumber(overview.metrics.pets), "Profili nel database", "/pets"],
    ["Conversazioni", formatNumber(overview.metrics.conversations), "Conversazioni persistite", "/moderation"],
    ["Radar places", formatNumber(overview.metrics.radar_places), "OSM + open datasets", "/data/geographic"],
    ["Moderazione", formatNumber(overview.metrics.open_moderation), "Elementi aperti", "/moderation"],
    ["Scrape runs", formatNumber(overview.metrics.scrape_runs), "Esecuzioni registrate", "/jobs"],
  ];

  return (
    <AdminShell title="Overview" eyebrow="Operations">
      <div className="metric-grid metric-grid-six">
        {metrics.map(([label, value, note, href]) => (
          <Link className="metric-card overview-link" key={label} href={href}>
            <span>{label}</span>
            <strong>{value}</strong>
            <small>{note}</small>
          </Link>
        ))}
      </div>

      {overview.detail_available ? (
        <div className="two-column">
          <section className="panel kpi-detail-panel overview-panel-link">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">Users KPI</p>
                <h2><Link href="/users">Account detail <span aria-hidden="true">↗</span></Link></h2>
              </div>
            </div>
            <div className="mini-kpi-grid">
              <Link href="/users" className="overview-kpi-link"><span>Auth accounts</span><strong>{overview.user_details.auth_accounts}</strong></Link>
              <Link href="/users" className="overview-kpi-link"><span>Owner profiles</span><strong>{overview.user_details.profiles}</strong></Link>
              <Link href="/data/geographic" className="overview-kpi-link"><span>Geolocated</span><strong>{overview.user_details.geolocated}</strong></Link>
              <Link href="/pets" className="overview-kpi-link"><span>With pets</span><strong>{overview.user_details.with_pets}</strong></Link>
              <Link href="/users" className="overview-kpi-link"><span>New 7d</span><strong>{overview.user_details.new_7d}</strong></Link>
              <Link href="/users" className="overview-kpi-link"><span>New 30d</span><strong>{overview.user_details.new_30d}</strong></Link>
            </div>
          </section>

          <section className="panel kpi-detail-panel">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">Pets KPI</p>
                <h2><Link href="/pets">Pet detail <span aria-hidden="true">↗</span></Link></h2>
              </div>
            </div>
            <div className="mini-kpi-grid">
              <Link className="overview-kpi-link" href="/pets"><span>Total</span><strong>{overview.pet_details.total}</strong></Link>
              <Link className="overview-kpi-link" href="/pets?status=active"><span>Active flag</span><strong>{overview.pet_details.active}</strong></Link>
              <Link className="overview-kpi-link" href="/pets?status=exotic"><span>Exotic</span><strong>{overview.pet_details.exotic}</strong></Link>
              <Link className="overview-kpi-link" href="/pets?status=memorial"><span>Memorial</span><strong>{overview.pet_details.memorial}</strong></Link>
              {Object.entries(overview.pet_details.species).map(([species, count]) => (
                <Link key={species} className="overview-kpi-link" href={`/pets?species=${encodeURIComponent(species)}`}>
                  <span>{speciesLabels[species] ?? species}</span>
                  <strong>{count}</strong>
                </Link>
              ))}
            </div>
          </section>
        </div>
      ) : (
        <section className="panel">
          <p className="eyebrow">Detailed KPI</p>
          <h2>Backend update pending</h2>
          <p className="muted">
            The top-level counters remain live. User and pet detail palettes will activate
            automatically as soon as the matching backend deployment is available.
          </p>
        </section>
      )}

      <div className="two-column wide-left">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Geographic data</p>
              <h2><Link href="/data/geographic">Data sources <span aria-hidden="true">↗</span></Link></h2>
            </div>
            <span className="tag">{formatNumber(overview.metrics.radar_places)} POI</span>
          </div>
          <div className="data-table overview-source-table">
            <div className="table-row table-head">
              <span>Source</span><span>Release</span><span>Records</span><span>Imported</span>
            </div>
            {overview.data_sources.map((source) => (
              <Link className="table-row overview-table-link" href="/data/geographic" key={source.source}>
                <span>{source.source}</span>
                <span>{source.release}</span>
                <span>{formatNumber(source.place_count)}</span>
                <span>{formatDate(source.imported_at)}</span>
              </Link>
            ))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Moderation</p>
              <h2><Link href="/moderation">Open queue <span aria-hidden="true">↗</span></Link></h2>
            </div>
          </div>
          <div className="operation-list">
            <Link href="/moderation"><strong>{overview.moderation.radar_reports}</strong><span>Radar reports</span></Link>
            <Link href="/moderation"><strong>{overview.moderation.chat_reports}</strong><span>Chat response reports</span></Link>
            <Link href="/moderation"><strong>{overview.moderation.marketplace_reports}</strong><span>Marketplace reports</span></Link>
          </div>
        </section>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Operations</p>
            <h2><Link href="/jobs">Recent ingestion activity <span aria-hidden="true">↗</span></Link></h2>
          </div>
          <span className="tag">read-only</span>
        </div>
        <div className="data-table recent-runs-table">
          <div className="table-row table-head">
            <span>Engine</span><span>Status</span><span>Coverage</span><span>Records</span><span>Finished</span>
          </div>
          {overview.recent_runs.length ? overview.recent_runs.map((run) => (
            <Link className="table-row overview-table-link" href="/jobs" key={run.id}>
              <span>{run.engine}</span>
              <span>{run.status}</span>
              <span>{run.coverage_key ?? "—"}</span>
              <span>{formatNumber(run.place_count ?? 0)}</span>
              <span>{formatDate(run.finished_at)}</span>
            </Link>
          )) : (
            <div className="table-empty">Nessun job registrato.</div>
          )}
        </div>
      </section>
    </AdminShell>
  );
}
