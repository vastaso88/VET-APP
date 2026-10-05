import { AdminShell } from "../../../components/admin-shell";

const sources = [
  ["OpenStreetMap", "8,069", "Active", "Radar import script available"],
  ["Open data", "16,235", "Active", "Imported source datasets"],
  ["Radar cache", "1,052", "Active", "Runtime/cache layer"],
];

export default function GeographicDataPage() {
  return (
    <AdminShell title="Geographic data" eyebrow="Data operations">
      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Sources</p>
            <h2>Territorial datasets</h2>
          </div>
          <button className="primary-button" disabled>New ingestion</button>
        </div>

        <div className="data-table">
          <div className="table-row table-head">
            <span>Source</span><span>Records</span><span>Status</span><span>Notes</span>
          </div>
          {sources.map((row) => (
            <div className="table-row" key={row[0]}>
              {row.map((cell) => <span key={cell}>{cell}</span>)}
            </div>
          ))}
        </div>
      </section>

      <section className="panel">
        <p className="eyebrow">Next connection</p>
        <h2>Zonal ingestion</h2>
        <p className="muted">
          The first live workflow will expose dry-run and execution for a geographic scope
          (country / region / province / bounding box) while reusing the existing Radar scripts.
        </p>
      </section>
    </AdminShell>
  );
}
