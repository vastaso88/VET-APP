import { AdminShell } from "../../../components/admin-shell";

const upstream = [
  ["Europe PMC", "Discovery + literature", "Available"],
  ["PubMed", "Biomedical metadata", "Available"],
  ["Crossref", "DOI metadata", "Available"],
  ["OpenAlex", "Bibliographic enrichment", "Available"],
];

export default function ScientificDataPage() {
  return (
    <AdminShell title="Scientific data" eyebrow="Knowledge operations">
      <div className="two-column wide-left">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Upstream</p>
              <h2>Evidence sources</h2>
            </div>
            <button className="primary-button" disabled>Discover papers</button>
          </div>
          <div className="data-table scientific-table">
            <div className="table-row table-head">
              <span>Provider</span><span>Role</span><span>Status</span>
            </div>
            {upstream.map((row) => (
              <div className="table-row" key={row[0]}>
                {row.map((cell) => <span key={cell}>{cell}</span>)}
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <p className="eyebrow">Pipeline</p>
          <h2>Scientific ingestion</h2>
          <ol className="pipeline">
            <li>Discover</li>
            <li>Normalize + deduplicate</li>
            <li>Integrity / quality evaluation</li>
            <li>Species + clinical classification</li>
            <li>Index for retrieval</li>
          </ol>
        </section>
      </div>
    </AdminShell>
  );
}
