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

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Trusted source governance</p>
            <h2>Trusted domains</h2>
          </div>
          <span className="tag">{catalog.trusted_domains.length} configured</span>
        </div>

        <div className="data-table trusted-domains-table">
          <div className="table-row table-head">
            <span>Domain</span>
            <span>Role</span>
            <span>Authority</span>
            <span>Vet relevance</span>
            <span>Policy</span>
            <span>Direct ingest</span>
            <span>Status</span>
          </div>
          {catalog.trusted_domains.map((domain) => (
            <div className="table-row" key={domain.id}>
              <span>
                <strong>{domain.display_name}</strong>
                <small>{domain.host}</small>
                {domain.notes ? <small>{domain.notes}</small> : null}
              </span>
              <span>{domain.discovery_only ? "Discovery / ranking" : domain.source_kind}</span>
              <span>{Number(domain.authority_score).toFixed(3)}</span>
              <span>{Number(domain.veterinary_relevance_score).toFixed(3)}</span>
              <span>{domain.evidence_policy}</span>
              <span>{domain.allowed_for_direct_ingest ? "yes" : "no"}</span>
              <span>{domain.is_active ? "active" : "disabled"}</span>
            </div>
          ))}
        </div>

        <details className="registry-details">
          <summary>Ranking / registry inputs ({catalog.registries.length})</summary>
          <div className="data-table registry-table">
            <div className="table-row table-head">
              <span>Registry</span><span>Kind</span><span>Metric</span><span>Weight</span><span>Status</span>
            </div>
            {catalog.registries.map((registry) => (
              <div className="table-row" key={registry.registry_key}>
                <span>{registry.display_name}</span>
                <span>{registry.registry_kind}</span>
                <span>{registry.metric_name}</span>
                <span>{Number(registry.weight).toFixed(3)}</span>
                <span>{registry.is_active ? "active" : "disabled"}</span>
              </div>
            ))}
          </div>
        </details>
      </section>

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
