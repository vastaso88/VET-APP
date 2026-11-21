"use client";

import { useActionState, useMemo, useState } from "react";

import {
  runGeographicOperation,
  type GeographicActionState,
} from "../app/data/geographic/actions";
import { GeographicCenterPicker } from "./geographic-center-picker";

const initialState: GeographicActionState = { status: "idle" };

const DEFAULT_LATITUDE = "45.4642";
const DEFAULT_LONGITUDE = "9.1900";
const DEFAULT_RADIUS_KM = "10";

export function GeographicIngestionPanel() {
  const [state, action, pending] = useActionState(runGeographicOperation, initialState);
  const [latitude, setLatitude] = useState(DEFAULT_LATITUDE);
  const [longitude, setLongitude] = useState(DEFAULT_LONGITUDE);
  const [radiusKm, setRadiusKm] = useState(DEFAULT_RADIUS_KM);

  const center = useMemo(() => {
    const lat = Number(latitude);
    const lng = Number(longitude);
    if (latitude === "" || longitude === "" || !Number.isFinite(lat) || !Number.isFinite(lng)) {
      return null;
    }
    return { latitude: lat, longitude: lng };
  }, [latitude, longitude]);

  return (
    <section className="panel">
      <div className="panel-heading">
        <div>
          <p className="eyebrow">Live Overpass workflow</p>
          <h2>Zonal ingestion</h2>
        </div>
      </div>

      <GeographicCenterPicker
        center={center}
        radiusKm={Number(radiusKm) > 0 ? Number(radiusKm) : 0}
        onPick={(picked) => {
          setLatitude(String(picked.latitude));
          setLongitude(String(picked.longitude));
        }}
      />
      <p className="muted">
        Clicca sulla mappa per impostare il centro. Puoi anche modificare le coordinate a mano.
      </p>

      <form action={action} className="operation-form">
        <label>
          Latitude
          <input
            name="latitude"
            type="number"
            step="0.000001"
            value={latitude}
            onChange={(event) => setLatitude(event.target.value)}
            required
          />
        </label>
        <label>
          Longitude
          <input
            name="longitude"
            type="number"
            step="0.000001"
            value={longitude}
            onChange={(event) => setLongitude(event.target.value)}
            required
          />
        </label>
        <label>
          Search radius (km)
          <input
            name="radius_km"
            type="number"
            step="1"
            min="1"
            max="50"
            value={radiusKm}
            onChange={(event) => setRadiusKm(event.target.value)}
            required
          />
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
