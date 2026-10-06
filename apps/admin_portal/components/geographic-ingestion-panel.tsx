"use client";

import { useActionState } from "react";

import {
  runGeographicOperation,
  type GeographicActionState,
} from "../app/data/geographic/actions";

const initialState: GeographicActionState = { status: "idle" };

export function GeographicIngestionPanel() {
  const [state, action, pending] = useActionState(runGeographicOperation, initialState);

  return (
    <section className="panel">
      <div className="panel-heading">
        <div>
          <p className="eyebrow">Live Overpass workflow</p>
          <h2>Zonal ingestion</h2>
        </div>
      </div>

      <form action={action} className="operation-form">
        <label>
          Latitude
          <input name="latitude" type="number" step="0.000001" defaultValue="45.4642" required />
        </label>
        <label>
          Longitude
          <input name="longitude" type="number" step="0.000001" defaultValue="9.1900" required />
        </label>
        <label>
          Search radius (km)
          <input name="radius_km" type="number" step="1" min="1" max="50" defaultValue="10" required />
        </label>
        <div className="form-actions">
          <button
            className="ghost-button"
            type="submit"
            name="operation"
            value="preview"
            disabled={pending}
          >
            {pending ? "Running…" : "Preview"}
          </button>
          <button
            className="primary-button"
            type="submit"
            name="operation"
            value="execute"
            disabled={pending}
          >
            {pending ? "Running…" : "Execute ingestion"}
          </button>
        </div>
      </form>

      {state.message ? (
        <div className={state.status === "error" ? "operation-error" : "operation-result-message"}>
          {state.message}
        </div>
      ) : null}

      {state.result ? (
        <div className="operation-result">
          <div className="metric-grid">
            <article className="metric-card">
              <span>Places found</span>
              <strong>{state.result.place_count}</strong>
              <small>{state.result.source}</small>
            </article>
            <article className="metric-card">
              <span>Search radius</span>
              <strong>{state.result.search_radius_km} km</strong>
              <small>requested</small>
            </article>
            <article className="metric-card">
              <span>Ingestion radius</span>
              <strong>{state.result.ingestion_radius_km} km</strong>
              <small>cell coverage</small>
            </article>
          </div>

          <p className="muted">
            Coverage: <code>{state.result.coverage_key}</code>
            {state.result.job_id ? <> · Job: <code>{state.result.job_id}</code></> : null}
          </p>

          <div className="data-table operation-sample-table">
            <div className="table-row table-head">
              <span>Type</span><span>Name</span><span>City</span><span>Address</span>
            </div>
            {state.result.sample.map((place) => (
              <div className="table-row" key={place.source_external_id}>
                <span>{place.place_type}</span>
                <span>{place.name}</span>
                <span>{place.city ?? "—"}</span>
                <span>{place.address_label ?? "—"}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </section>
  );
}
