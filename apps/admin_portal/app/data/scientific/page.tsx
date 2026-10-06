import { AdminShell } from "../../../components/admin-shell";
import { ScientificDiscoveryPanel } from "../../../components/scientific-discovery-panel";
import { getScientificCatalog } from "../../../lib/admin-api";

function date(value: string): string {
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function ScientificDataPage() {
  const catalog = await getScientificCatalog();

  return (
    <AdminShell title="Scientific data" eyebrow="Knowledge operations">
      <div className="metric-grid">
        <article className="metric-card">
          <span>Trusted domains</span>
          <strong>{catalog.metrics.trusted_domains}</strong>
          <small>ai.trusted_source_domains</small>
        </article>
        <article className="metric-card">
          <span>Documents</span>
          <strong>{catalog.metrics.documents}</strong>
          <small>ai.source_documents</small>
        </article>
        <article className="metric-card">
          <span>RAG eligible</span>
          <strong>{catalog.metrics.eligible_for_rag}</strong>
          <small>verification gate</small>
        </article>
        <article className="metric-card">
          <span>Embedded</span>
          <strong>{catalog.metrics.embedded}</strong>
          <small>{catalog.metrics.chunks} chunks</small>
        </article>
      </div>

      <ScientificDiscoveryPanel />

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Scientific catalog</p>
            <h2>Recent source documents</h2>
          </div>
        </div>
        <div className="data-table scientific-catalog-table">
          <div className="table-row table-head">
            <span>Added</span><span>Tier</span><span>Year</span><span>Paper</span><span>Source</span><span>Status</span><span>RAG</span>
          </div>
          {catalog.recent_documents.length ? catalog.recent_documents.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.created_at)}</span>
              <span>{item.reliability_tier}</span>
              <span>{item.publication_year ?? "—"}</span>
              <span>
                <a href={item.canonical_url} target="_blank" rel="noreferrer">{item.title}</a>
              </span>
              <span>{item.source_name}</span>
              <span>{item.ingestion_status} / {item.embedding_status}</span>
              <span>{item.eligible_for_rag ? "yes" : "no"}</span>
            </div>
          )) : <div className="table-empty">No scientific documents ingested yet.</div>}
        </div>
      </section>
    </AdminShell>
  );
}
