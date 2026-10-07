import Link from "next/link";
import { notFound } from "next/navigation";

import { AdminShell } from "../../../../components/admin-shell";
import { getModerationDetail } from "../../../../lib/admin-api";
import {
  resolveChatReport,
  resolveMarketplaceReport,
  resolveRadarReport,
} from "../../actions";

function value(item: Record<string, unknown>, key: string): string {
  const raw = item[key];
  if (raw === null || raw === undefined || raw === "") return "—";
  if (typeof raw === "object") return JSON.stringify(raw);
  return String(raw);
}

function dateValue(item: Record<string, unknown>, key: string): string {
  const raw = item[key];
  if (!raw) return "—";
  const parsed = new Date(String(raw));
  if (Number.isNaN(parsed.getTime())) return String(raw);
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "medium",
    timeStyle: "medium",
  }).format(parsed);
}

export default async function ModerationDetailPage({
  params,
}: {
  params: Promise<{ queue: string; id: string }>;
}) {
  const { queue, id } = await params;
  if (!["radar", "chat", "marketplace"].includes(queue)) notFound();

  const detail = await getModerationDetail(
    queue as "radar" | "chat" | "marketplace",
    id,
  );

  if (!detail) {
    return (
      <AdminShell title="Moderation detail" eyebrow={queue}>
        <div>
          <Link className="table-action-link" href="/moderation">← Back to moderation</Link>
        </div>
        <section className="panel">
          <p className="eyebrow">Backend update pending</p>
          <h2>Detail actions are temporarily unavailable</h2>
          <p className="muted">
            The moderation queue remains readable. This detail endpoint will activate
            automatically when the matching backend deployment is available.
          </p>
        </section>
      </AdminShell>
    );
  }

  const item = detail.item;
  const listing =
    queue === "marketplace" && item.listing && typeof item.listing === "object"
      ? item.listing as Record<string, unknown>
      : null;

  return (
    <AdminShell title="Moderation detail" eyebrow={queue}>
      <div>
        <Link className="table-action-link" href="/moderation">← Back to moderation</Link>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Report</p>
            <h2>{value(item, "reason") !== "—" ? value(item, "reason") : value(item, "kind")}</h2>
          </div>
          <span className="tag">{value(item, "status")}</span>
        </div>

        <div className="detail-grid">
          <div><span>ID</span><strong>{value(item, "id")}</strong></div>
          <div><span>Created</span><strong>{dateValue(item, "created_at")}</strong></div>
          <div><span>Resolved</span><strong>{dateValue(item, "resolved_at")}</strong></div>
          {queue === "radar" ? (
            <>
              <div><span>Kind</span><strong>{value(item, "kind")}</strong></div>
              <div><span>Place type</span><strong>{value(item, "place_type")}</strong></div>
              <div><span>Name</span><strong>{value(item, "name")}</strong></div>
              <div><span>Address</span><strong>{value(item, "address_label")}</strong></div>
              <div><span>Coordinates</span><strong>{value(item, "latitude")}, {value(item, "longitude")}</strong></div>
              <div><span>Target</span><strong>{value(item, "target_source")} / {value(item, "target_source_id")}</strong></div>
              <div><span>Confirmations</span><strong>{value(item, "confirmations")}</strong></div>
              <div><span>Denials</span><strong>{value(item, "denials")}</strong></div>
              <div><span>Admin note</span><strong>{value(item, "admin_resolution_note")}</strong></div>
            </>
          ) : null}
          {queue === "chat" ? (
            <>
              <div><span>Conversation</span><strong>{value(item, "conversation_id")}</strong></div>
              <div><span>Message</span><strong>{value(item, "message_id")}</strong></div>
              <div><span>Pet</span><strong>{value(item, "pet_id")}</strong></div>
              <div><span>Details</span><strong>{value(item, "details")}</strong></div>
              <div><span>Resolution note</span><strong>{value(item, "resolution_note")}</strong></div>
            </>
          ) : null}
          {queue === "marketplace" ? (
            <>
              <div><span>Listing ID</span><strong>{value(item, "listing_id")}</strong></div>
              <div><span>Reporter</span><strong>{value(item, "reporter_owner_id")}</strong></div>
              <div><span>Resolution action</span><strong>{value(item, "resolution_action")}</strong></div>
              <div><span>Resolution note</span><strong>{value(item, "resolution_note")}</strong></div>
            </>
          ) : null}
        </div>

        {queue === "chat" ? (
          <div className="detail-copy">
            <h3>Reported answer</h3>
            <pre className="report-answer">{value(item, "reported_answer")}</pre>
          </div>
        ) : null}

        {queue === "radar" && detail.votes?.length ? (
          <div className="detail-copy">
            <h3>Votes</h3>
            <div className="compact-list">
              {detail.votes.map((vote, index) => (
                <span key={`${vote.created_at}-${index}`}>
                  {vote.vote > 0 ? "confirm" : "deny"} · {vote.created_at}
                </span>
              ))}
            </div>
          </div>
        ) : null}
      </section>

      {listing ? (
        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Marketplace listing</p>
              <h2>{value(listing, "title")}</h2>
            </div>
            <span className="tag">{value(listing, "status")}</span>
          </div>
          <div className="detail-grid">
            <div><span>Owner</span><strong>{value(listing, "owner_id")}</strong></div>
            <div><span>Category</span><strong>{value(listing, "category")}</strong></div>
            <div><span>Condition</span><strong>{value(listing, "condition")}</strong></div>
            <div><span>Price cents</span><strong>{value(listing, "price_cents")}</strong></div>
            <div><span>City</span><strong>{value(listing, "city_label")}</strong></div>
            <div><span>Reports</span><strong>{value(listing, "report_count")}</strong></div>
          </div>
          <div className="detail-copy">
            <h3>Description</h3>
            <p>{value(listing, "description")}</p>
          </div>
        </section>
      ) : null}

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Admin action</p>
            <h2>Resolve report</h2>
          </div>
        </div>

        {queue === "radar" ? (
          <form action={resolveRadarReport} className="moderation-action-form">
            <input type="hidden" name="report_id" value={id} />
            <label>
              Note
              <input name="resolution_note" placeholder="Optional moderation note" />
            </label>
            <div className="form-actions">
              <button className="primary-button" name="action" value="confirm">Confirm</button>
              <button className="danger-button" name="action" value="reject">Reject</button>
              <button className="ghost-button" name="action" value="reopen">Reopen</button>
            </div>
          </form>
        ) : null}

        {queue === "chat" ? (
          <form action={resolveChatReport} className="moderation-action-form">
            <input type="hidden" name="report_id" value={id} />
            <label>
              Note
              <input name="resolution_note" placeholder="Optional moderation note" />
            </label>
            <div className="form-actions">
              <button className="ghost-button" name="status" value="under_review">Under review</button>
              <button className="primary-button" name="status" value="resolved">Resolve</button>
              <button className="danger-button" name="status" value="wont_fix">Won&apos;t fix</button>
            </div>
          </form>
        ) : null}

        {queue === "marketplace" ? (
          <form action={resolveMarketplaceReport} className="moderation-action-form">
            <input type="hidden" name="report_id" value={id} />
            <label>
              Note
              <input name="resolution_note" placeholder="Optional moderation note" />
            </label>
            <div className="form-actions">
              <button className="danger-button" name="action" value="remove_listing">Remove listing</button>
              <button className="primary-button" name="action" value="dismiss_report">Dismiss / keep listing</button>
              <button className="ghost-button" name="action" value="restore_listing">Restore listing</button>
              <button className="ghost-button" name="action" value="reopen_report">Reopen report</button>
            </div>
          </form>
        ) : null}
      </section>
    </AdminShell>
  );
}
