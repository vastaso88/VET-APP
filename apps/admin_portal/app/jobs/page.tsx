import { AdminShell } from "../../components/admin-shell";
import { getAdminJobs } from "../../lib/admin-api";

function date(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

function sourceNames(value: unknown): string {
  if (Array.isArray(value)) return value.map(String).join(", ");
  if (typeof value === "string") return value;
  return "—";
}

export default async function JobsPage() {
  const jobs = await getAdminJobs();

  return (
    <AdminShell title="Ingestion jobs" eyebrow="Data operations">
      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Unified execution log</p>
            <h2>scrape_runs</h2>
          </div>
          <span className="tag">{jobs.length} loaded</span>
        </div>

        <div className="data-table jobs-table">
          <div className="table-row table-head">
            <span>Requested</span>
            <span>Engine</span>
            <span>Status</span>
            <span>Source</span>
            <span>Coverage</span>
            <span>Places</span>
            <span>Duration / error</span>
          </div>
          {jobs.length ? jobs.map((job) => {
            const started = job.started_at ? new Date(job.started_at).getTime() : null;
            const finished = job.finished_at ? new Date(job.finished_at).getTime() : null;
            const seconds =
              started !== null && finished !== null
                ? Math.max(0, Math.round((finished - started) / 1000))
                : null;
            return (
              <div className="table-row" key={job.id}>
                <span>{date(job.requested_at ?? job.created_at)}</span>
                <span>{job.engine}</span>
                <span>{job.status}</span>
                <span>{sourceNames(job.source_names)}</span>
                <span><code>{job.coverage_key ?? "—"}</code></span>
                <span>{job.place_count ?? 0}</span>
                <span>
                  {job.error_message
                    ? <details><summary>Error</summary><pre className="job-error">{job.error_message}</pre></details>
                    : seconds !== null ? `${seconds}s` : "—"}
                </span>
              </div>
            );
          }) : <div className="table-empty">No ingestion jobs.</div>}
        </div>
      </section>
    </AdminShell>
  );
}
