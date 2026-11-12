"use client";

import { useMemo, useState } from "react";

import type { AdminJob } from "../lib/admin-api";

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

export function JobsFilterTable({ jobs }: { jobs: AdminJob[] }) {
  const [engine, setEngine] = useState("");
  const [status, setStatus] = useState("");
  const [source, setSource] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const engines = useMemo(
    () => Array.from(new Set(jobs.map((job) => job.engine))).sort(),
    [jobs],
  );
  const statuses = useMemo(
    () => Array.from(new Set(jobs.map((job) => job.status))).sort(),
    [jobs],
  );

  const filtered = useMemo(() => {
    const fromTime = from ? new Date(`${from}T00:00:00`).getTime() : null;
    const toTime = to ? new Date(`${to}T23:59:59`).getTime() : null;
    const sourceNeedle = source.trim().toLowerCase();

    return jobs.filter((job) => {
      if (engine && job.engine !== engine) return false;
      if (status && job.status !== status) return false;
      if (
        sourceNeedle &&
        !sourceNames(job.source_names).toLowerCase().includes(sourceNeedle) &&
        !(job.coverage_key ?? "").toLowerCase().includes(sourceNeedle)
      ) {
        return false;
      }
      const requested = new Date(job.requested_at ?? job.created_at).getTime();
      if (fromTime !== null && requested < fromTime) return false;
      if (toTime !== null && requested > toTime) return false;
      return true;
    });
  }, [jobs, engine, status, source, from, to]);

  return (
    <>
      <div className="job-filters">
        <label>
          Engine
          <select value={engine} onChange={(event) => setEngine(event.target.value)}>
            <option value="">All</option>
            {engines.map((item) => <option key={item} value={item}>{item}</option>)}
          </select>
        </label>
        <label>
          Status
          <select value={status} onChange={(event) => setStatus(event.target.value)}>
            <option value="">All</option>
            {statuses.map((item) => <option key={item} value={item}>{item}</option>)}
          </select>
        </label>
        <label>
          Source / coverage
          <input
            value={source}
            onChange={(event) => setSource(event.target.value)}
            placeholder="openstreetmap, scientific…"
          />
        </label>
        <label>
          From
          <input type="date" value={from} onChange={(event) => setFrom(event.target.value)} />
        </label>
        <label>
          To
          <input type="date" value={to} onChange={(event) => setTo(event.target.value)} />
        </label>
        <button
          className="ghost-button"
          type="button"
          onClick={() => {
            setEngine("");
            setStatus("");
            setSource("");
            setFrom("");
            setTo("");
          }}
        >
          Reset
        </button>
      </div>

      <div className="filter-count">{filtered.length} / {jobs.length} jobs</div>

      <div className="data-table jobs-table">
        <div className="table-row table-head">
          <span>Requested</span>
          <span>Engine</span>
          <span>Status</span>
          <span>Source</span>
          <span>Coverage</span>
          <span>Records</span>
          <span>Duration / error</span>
        </div>
        {filtered.length ? filtered.map((job) => {
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
        }) : <div className="table-empty">No jobs match the active filters.</div>}
      </div>
    </>
  );
}
