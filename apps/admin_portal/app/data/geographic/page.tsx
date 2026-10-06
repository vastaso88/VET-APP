import { AdminShell } from "../../../components/admin-shell";
import { GeographicIngestionPanel } from "../../../components/geographic-ingestion-panel";
import { GeographicWorldMap } from "../../../components/geographic-world-map";
import { getAdminGeographic } from "../../../lib/admin-api";

function formatNumber(value: number): string {
  return new Intl.NumberFormat("it-IT").format(value);
}

function date(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function GeographicDataPage() {
  const geographic = await getAdminGeographic();

  return (
    <AdminShell title="Geographic data" eyebrow="Data operations">
      <div className="metric-grid">
        <article className="metric-card">
          <span>OSM catalog</span>
          <strong>{formatNumber(geographic.counts.osm)}</strong>
          <small>radar_places_osm</small>
        </article>
        <article className="metric-card">
          <span>Open datasets</span>
          <strong>{formatNumber(geographic.counts.open)}</strong>
          <small>radar_places_open</small>
        </article>
        <article className="metric-card">
          <span>Live cache</span>
          <strong>{formatNumber(geographic.counts.cache)}</strong>
          <small>radar_places_cache</small>
        </article>
      </div>

      <section className="panel map-panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">World coverage</p>
            <h2>Users + ingested zones</h2>
          </div>
          <span className="tag">{geographic.users.length} users · {geographic.coverage.length} cells</span>
        </div>
        <p className="muted">
          User pins are shown over the global map. Coverage areas use five freshness bands:
          green is recent, red is obsolete; fills are rendered at 30% opacity.
        </p>
        <GeographicWorldMap users={geographic.users} coverage={geographic.coverage} />
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Sources</p>
            <h2>Territorial datasets</h2>
          </div>
        </div>

        <div className="data-table geographic-source-table">
          <div className="table-row table-head">
            <span>Source</span><span>Release</span><span>Records</span><span>Imported</span><span>License</span>
          </div>
          {geographic.sources.map((source) => (
            <div className="table-row" key={source.source}>
              <span>{source.source}</span>
              <span>{source.release}</span>
              <span>{formatNumber(source.place_count)}</span>
              <span>{date(source.imported_at)}</span>
              <span>{source.license ?? "—"}</span>
            </div>
          ))}
        </div>
      </section>

      <GeographicIngestionPanel />

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Live cache</p>
            <h2>Recent coverage cells</h2>
          </div>
        </div>
        <div className="data-table coverage-table">
          <div className="table-row table-head">
            <span>Coverage</span><span>Center</span><span>Radius</span><span>Places</span><span>Refreshed</span><span>Expires</span>
          </div>
          {geographic.coverage.length ? geographic.coverage.map((cell) => (
            <div className="table-row" key={cell.coverage_key}>
              <span><code>{cell.coverage_key}</code></span>
              <span>{cell.center_latitude.toFixed(2)}, {cell.center_longitude.toFixed(2)}</span>
              <span>{cell.radius_km} km</span>
              <span>{formatNumber(cell.place_count)}</span>
              <span>{date(cell.refreshed_at)}</span>
              <span>{date(cell.expires_at)}</span>
            </div>
          )) : <div className="table-empty">No live coverage cells.</div>}
        </div>
      </section>
    </AdminShell>
  );
}
