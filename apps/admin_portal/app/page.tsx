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
    ["Account", formatNumber(overview.metrics.users), "Supabase Auth"],
    ["Pet", formatNumber(overview.metrics.pets), "Profili nel database"],
    ["Conversazioni", formatNumber(overview.metrics.conversations), "Conversazioni persistite"],
    ["Radar places", formatNumber(overview.metrics.radar_places), "OSM + open datasets"],
    ["Moderazione", formatNumber(overview.metrics.open_moderation), "Elementi aperti"],
    ["Scrape runs", formatNumber(overview.metrics.scrape_runs), "Esecuzioni registrate"],
  ];

  return (
    <AdminShell title="Overview" eyebrow="Operations">
      <div className="metric-grid metric-grid-six">
        {metrics.map(([label, value, note]) => (
          <article className="metric-card" key={label}>
            <span>{label}</span>
            <strong>{value}</strong>
            <small>{note}</small>
          </article>
        ))}
      </div>

      {overview.detail_available ? (
        <div className="two-column">
          <section className="panel kpi-detail-panel">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">Users KPI</p>
                <h2>Account detail</h2>
              </div>
            </div>
            <div className="mini-kpi-grid">
              <div><span>Auth accounts</span><strong>{overview.user_details.auth_accounts}</strong></div>
              <div><span>Owner profiles</span><strong>{overview.user_details.profiles}</strong></div>
              <div><span>Geolocated</span><strong>{overview.user_details.geolocated}</strong></div>
              <div><span>With pets</span><strong>{overview.user_details.with_pets}</strong></div>
              <div><span>New 7d</span><strong>{overview.user_details.new_7d}</strong></div>
              <div><span>New 30d</span><strong>{overview.user_details.new_30d}</strong></div>
            </div>
          </section>

          <section className="panel kpi-detail-panel">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">Pets KPI</p>
                <h2>Pet detail</h2>
              </div>
            </div>
            <div className="mini-kpi-grid">
              <div><span>Total</span><strong>{overview.pet_details.total}</strong></div>
              <div><span>Active flag</span><strong>{overview.pet_details.active}</strong></div>
              <div><span>Exotic</span><strong>{overview.pet_details.exotic}</strong></div>
              <div><span>Memorial</span><strong>{overview.pet_details.memorial}</strong></div>
              {Object.entries(overview.pet_details.species).map(([species, count]) => (
                <div key={species}>
                  <span>{speciesLabels[species] ?? species}</span>
                  <strong>{count}</strong>
                </div>
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
              <h2>Data sources</h2>
            </div>
            <span className="tag">{formatNumber(overview.metrics.radar_places)} POI</span>
          </div>
          <div className="data-table overview-source-table">
            <div className="table-row table-head">
              <span>Source</span><span>Release</span><span>Records</span><span>Imported</span>
            </div>
            {overview.data_sources.map((source) => (
              <div className="table-row" key={source.source}>
                <span>{source.source}</span>
                <span>{source.release}</span>
                <span>{formatNumber(source.place_count)}</span>
                <span>{formatDate(source.imported_at)}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Moderation</p>
              <h2>Open queue</h2>
            </div>
          </div>
          <div className="operation-list">
            <div><strong>{overview.moderation.radar_reports}</strong><span>Radar reports</span></div>
            <div><strong>{overview.moderation.chat_reports}</strong><span>Chat response reports</span></div>
            <div><strong>{overview.moderation.marketplace_reports}</strong><span>Marketplace reports</span></div>
          </div>
        </section>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Operations</p>
            <h2>Recent ingestion activity</h2>
          </div>
          <span className="tag">read-only</span>
        </div>
        <div className="data-table recent-runs-table">
          <div className="table-row table-head">
            <span>Engine</span><span>Status</span><span>Coverage</span><span>Records</span><span>Finished</span>
          </div>
          {overview.recent_runs.length ? overview.recent_runs.map((run) => (
            <div className="table-row" key={run.id}>
              <span>{run.engine}</span>
              <span>{run.status}</span>
              <span>{run.coverage_key ?? "—"}</span>
              <span>{formatNumber(run.place_count ?? 0)}</span>
              <span>{formatDate(run.finished_at)}</span>
            </div>
          )) : (
            <div className="table-empty">Nessun job registrato.</div>
          )}
        </div>
      </section>
    </AdminShell>
  );
}
