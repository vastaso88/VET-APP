import { AdminShell } from "../../components/admin-shell";

export default function JobsPage() {
  return (
    <AdminShell title="Ingestion jobs" eyebrow="Data operations">
      <section className="panel empty-state">
        <div>
          <p className="eyebrow">Unified execution log</p>
          <h2>No admin-managed jobs yet</h2>
          <p className="muted">
            This page will track geographic and scientific ingestion with status, counters,
            scope, duration, errors and the admin who launched each operation.
          </p>
        </div>
      </section>
    </AdminShell>
  );
}
