"use client";

import { useActionState } from "react";

import {
  runScientificDiscovery,
  type ScientificActionState,
} from "../app/data/scientific/actions";

const initialState: ScientificActionState = { status: "idle" };

export function ScientificDiscoveryPanel() {
  const [state, action, pending] = useActionState(runScientificDiscovery, initialState);

  return (
    <section className="panel">
      <div className="panel-heading">
        <div>
          <p className="eyebrow">Live evidence retrieval</p>
          <h2>Discover / ingest papers</h2>
        </div>
      </div>

      <form action={action} className="scientific-form">
        <label className="wide-field">
          Query
          <input
            name="query"
            defaultValue="canine chronic kidney disease"
            required
          />
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
          <input name="max_results" type="number" min="1" max="20" defaultValue="10" />
        </label>
        <div className="form-actions">
          <button
            className="ghost-button"
            type="submit"
            name="operation"
            value="discover"
            disabled={pending}
          >
            {pending ? "Running…" : "Discover"}
          </button>
          <button
            className="primary-button"
            type="submit"
            name="operation"
            value="ingest"
            disabled={pending}
          >
            {pending ? "Running…" : "Ingest results"}
          </button>
        </div>
      </form>

      {state.message ? (
        <div className={state.status === "error" ? "operation-error" : "operation-result-message"}>
          {state.message}
        </div>
      ) : null}

      {state.result?.job_id ? (
        <p className="muted">
          Job: <code>{state.result.job_id}</code>
        </p>
      ) : null}

      {state.result ? (
        <div className="data-table scientific-results-table">
          <div className="table-row table-head">
            <span>Tier</span><span>Year</span><span>Paper</span><span>Journal</span><span>DOI / PMID</span><span>Access</span>
          </div>
          {state.result.results.map((item, index) => (
            <div className="table-row" key={item.doi ?? item.pmid ?? `${item.title}-${index}`}>
              <span>{item.tier}</span>
              <span>{item.year ?? "—"}</span>
              <span>
                {item.source_url ? (
                  <a href={item.source_url} target="_blank" rel="noreferrer">{item.title}</a>
                ) : item.title}
              </span>
              <span>{item.journal ?? "—"}</span>
              <span>{item.doi ?? item.pmid ?? "—"}</span>
              <span>{item.access_depth}</span>
            </div>
          ))}
        </div>
      ) : null}

      <p className="muted">
        Discover is read-only. Ingest stores deduplicated metadata in ai.source_documents.
        New records remain pending and not eligible for RAG until a later verification/full-text step.
      </p>
    </section>
  );
}
