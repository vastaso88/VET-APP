import { AdminShell } from "../../../components/admin-shell";
import { ScientificDiscoveryPanel } from "../../../components/scientific-discovery-panel";

export default async function ScientificDataPage() {
  return (
    <AdminShell title="Scientific data" eyebrow="Knowledge operations">
      <ScientificDiscoveryPanel />

      <section className="panel">
        <p className="eyebrow">Current boundary</p>
        <h2>Discovery is real; persistence is not wired yet</h2>
        <p className="muted">
          The query above uses the backend evidence retriever currently configured for the
          application. Results are retrieved, deduplicated and ranked by the existing evidence
          pipeline. This page does not claim that a paper is ingested into the database until a
          scientific document store is added.
        </p>
      </section>
    </AdminShell>
  );
}
