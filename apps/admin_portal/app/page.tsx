import { AdminShell } from "../components/admin-shell";

const metrics = [
  ["Users", "—", "Connect analytics API"],
  ["Pets", "—", "Connect operational DB"],
  ["Radar places", "24k+", "OSM + open datasets"],
  ["Scientific sources", "4+", "Europe PMC / PubMed / Crossref / OpenAlex"],
];

export default function OverviewPage() {
  return (
    <AdminShell title="Overview" eyebrow="Operations">
      <div className="metric-grid">
        {metrics.map(([label, value, note]) => (
          <article className="metric-card" key={label}>
            <span>{label}</span>
            <strong>{value}</strong>
            <small>{note}</small>
          </article>
        ))}
      </div>

      <div className="two-column">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Priority</p>
              <h2>Data operations</h2>
            </div>
            <span className="tag">v0.1</span>
          </div>
          <div className="operation-list">
            <div><strong>Geographic ingestion</strong><span>Existing Radar import pipelines</span></div>
            <div><strong>Scientific ingestion</strong><span>Evidence discovery and curation</span></div>
            <div><strong>Job history</strong><span>Unified execution and audit trail</span></div>
          </div>
        </section>

        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Guardrail</p>
              <h2>Admin boundary</h2>
            </div>
          </div>
          <p className="muted">
            This portal is intentionally separated from the Flutter user app. Privileged
            operations will be executed server-side through dedicated admin endpoints.
          </p>
        </section>
      </div>
    </AdminShell>
  );
}
