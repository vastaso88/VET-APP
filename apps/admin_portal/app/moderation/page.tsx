import { AdminShell } from "../../components/admin-shell";

const queues = [
  ["Radar reports", "1", "Place corrections and user reports"],
  ["Chat response reports", "0", "Unsafe / low-quality AI responses"],
  ["Marketplace reports", "0", "Listings requiring review"],
];

export default function ModerationPage() {
  return (
    <AdminShell title="Moderation" eyebrow="Trust & safety">
      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Unified queue</p>
            <h2>Items requiring attention</h2>
          </div>
        </div>
        <div className="data-table moderation-table">
          <div className="table-row table-head">
            <span>Queue</span><span>Open</span><span>Scope</span>
          </div>
          {queues.map((row) => (
            <div className="table-row" key={row[0]}>
              {row.map((cell) => <span key={cell}>{cell}</span>)}
            </div>
          ))}
        </div>
      </section>
    </AdminShell>
  );
}
