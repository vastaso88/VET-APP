import { AdminShell } from "../../components/admin-shell";
import { JobsFilterTable } from "../../components/jobs-filter-table";
import {
  getAdminJobs,
  getAdminSchedules,
} from "../../lib/admin-api";
import {
  createGeographicSchedule,
  createScientificSchedule,
  scheduleAction,
} from "./actions";

function date(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function JobsPage() {
  const [jobs, schedules] = await Promise.all([
    getAdminJobs(),
    getAdminSchedules(),
  ]);

  return (
    <AdminShell title="Ingestion jobs" eyebrow="Data operations">
      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Scheduler</p>
            <h2>Recurring ingestion</h2>
          </div>
          <span className="tag">{schedules.filter((item) => item.enabled).length} enabled</span>
        </div>

        <div className="two-column">
          <form action={createGeographicSchedule} className="scheduler-form">
            <h3>Geographic schedule</h3>
            <label>
              Name
              <input name="name" defaultValue="Milano geographic refresh" required />
            </label>
            <div className="scheduler-fields">
              <label>
                Every (hours)
                <input name="interval_hours" type="number" min="1" max="8760" defaultValue="168" required />
              </label>
              <label>
                Latitude
                <input name="latitude" type="number" step="0.000001" defaultValue="45.4642" required />
              </label>
              <label>
                Longitude
                <input name="longitude" type="number" step="0.000001" defaultValue="9.1900" required />
              </label>
              <label>
                Radius km
                <input name="radius_km" type="number" min="1" max="50" defaultValue="10" required />
              </label>
            </div>
            <label className="checkbox-label">
              <input name="run_immediately" type="checkbox" />
              Run on next scheduler tick
            </label>
            <button className="primary-button" type="submit">Create geographic schedule</button>
          </form>

          <form action={createScientificSchedule} className="scheduler-form">
            <h3>Scientific schedule</h3>
            <label>
              Name
              <input name="name" defaultValue="CKD evidence refresh" required />
            </label>
            <label>
              Query
              <input name="query" defaultValue="canine chronic kidney disease" required />
            </label>
            <div className="scheduler-fields">
              <label>
                Every (hours)
                <input name="interval_hours" type="number" min="1" max="8760" defaultValue="168" required />
              </label>
              <label>
                Species
                <select name="species" defaultValue="dog">
                  <option value="dog">dog</option>
                  <option value="cat">cat</option>
                  <option value="small_mammal">small_mammal</option>
                  <option value="bird">bird</option>
                  <option value="reptile_amphibian">reptile_amphibian</option>
                  <option value="fish">fish</option>
                  <option value="other">other</option>
                </select>
              </label>
              <label>
                Intent
                <select name="intent" defaultValue="clinical_question">
                  <option value="clinical_question">clinical_question</option>
                  <option value="nutrition_question">nutrition_question</option>
                  <option value="behavior_question">behavior_question</option>
                  <option value="preventive_care">preventive_care</option>
                </select>
              </label>
              <label>
                Max results
                <input name="max_results" type="number" min="1" max="20" defaultValue="10" required />
              </label>
            </div>
            <label className="checkbox-label">
              <input name="run_immediately" type="checkbox" />
              Run on next scheduler tick
            </label>
            <button className="primary-button" type="submit">Create scientific schedule</button>
          </form>
        </div>

        <div className="data-table schedule-table">
          <div className="table-row table-head">
            <span>Name</span><span>Engine</span><span>Every</span><span>Next run</span><span>Last run</span><span>Status</span><span>Actions</span>
          </div>
          {schedules.length ? schedules.map((schedule) => (
            <div className="table-row" key={schedule.id}>
              <span>
                <strong>{schedule.name}</strong>
                <small>{JSON.stringify(schedule.payload)}</small>
              </span>
              <span>{schedule.engine}</span>
              <span>{schedule.interval_hours}h</span>
              <span>{date(schedule.next_run_at)}</span>
              <span>{date(schedule.last_run_at)}</span>
              <span>
                {schedule.enabled ? "enabled" : "disabled"}
                {schedule.last_status ? ` · ${schedule.last_status}` : ""}
                {schedule.last_error ? (
                  <details><summary>Error</summary><pre className="job-error">{schedule.last_error}</pre></details>
                ) : null}
              </span>
              <span>
                <form action={scheduleAction} className="schedule-actions">
                  <input type="hidden" name="schedule_id" value={schedule.id} />
                  <button className="ghost-button" name="action" value="run_now">Run now</button>
                  <button
                    className="ghost-button"
                    name="action"
                    value={schedule.enabled ? "disable" : "enable"}
                  >
                    {schedule.enabled ? "Disable" : "Enable"}
                  </button>
                  <button className="danger-button" name="action" value="delete">Delete</button>
                </form>
              </span>
            </div>
          )) : <div className="table-empty">No recurring schedules configured.</div>}
        </div>

        <p className="muted">
          Due schedules are claimed atomically from Supabase and executed by the hourly GitHub runner. "Run now" executes the selected schedule immediately and resets its next recurrence.
        </p>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Unified execution log</p>
            <h2>scrape_runs</h2>
          </div>
          <span className="tag">{jobs.length} loaded</span>
        </div>

        <JobsFilterTable jobs={jobs} />
      </section>
    </AdminShell>
  );
}
