import Link from "next/link";

import { AdminShell } from "../../components/admin-shell";
import { MarketplaceRestrictForm } from "../../components/marketplace-restrict-form";
import { ModerationCaseActions } from "../../components/moderation-case-actions";
import { getAdminModeration, getListingReviews, getMarketplaceRestrictions, LISTING_REVIEW_LABELS } from "../../lib/admin-api";

function date(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function ModerationPage() {
  const [moderation, restrictions, listingReviews] = await Promise.all([
    getAdminModeration(),
    getMarketplaceRestrictions(),
    getListingReviews(),
  ]);
  const openReviews = listingReviews.filter((item) => item.status === "open");
  const activeRestrictions = restrictions.filter((item) => !item.lifted_at && (!item.expires_at || new Date(item.expires_at).getTime() > Date.now()));
  const openRadar = moderation.radar.filter((item) => item.status === "pending");
  const openChat = moderation.chat.filter(
    (item) => item.status === "reported" || item.status === "under_review",
  );
  const openMarketplace = moderation.marketplace.filter((item) => item.status === "open");
  const openMessages = moderation.marketplace_messages.filter((item) => item.status === "open");

  return (
    <AdminShell title="Moderation" eyebrow="Trust & safety">
      <ModerationCaseActions cases={[
        ...moderation.marketplace.filter(item => item.listing?.owner_id && !item.listing.owner_id.startsWith("deleted-")).map(item => ({ owner_id: item.listing!.owner_id, queue: "marketplace" as const, id: item.id })),
        ...moderation.marketplace_messages.filter(item => item.subject_owner_id && !item.subject_owner_id.startsWith("deleted-")).map(item => ({ owner_id: item.subject_owner_id!, queue: "marketplace_messages" as const, id: item.id })),
      ]} />
      <div className="metric-grid">
        <article className="metric-card">
          <span>Radar reports</span>
          <strong>{openRadar.length}</strong>
          <small>{moderation.radar.length} loaded</small>
        </article>
        <article className="metric-card">
          <span>Chat reports</span>
          <strong>{openChat.length}</strong>
          <small>{moderation.chat.length} loaded</small>
        </article>
        <article className="metric-card">
          <span>Marketplace reports</span>
          <strong>{openMarketplace.length}</strong>
          <small>{moderation.marketplace.length} loaded</small>
        </article>
        <article className="metric-card">
          <span>Marketplace messages</span>
          <strong>{openMessages.length}</strong>
          <small>{moderation.marketplace_messages.length} loaded</small>
        </article>
        <article className="metric-card">
          <span>Listings to check</span>
          <strong>{openReviews.length}</strong>
          <small>{listingReviews.length} loaded</small>
        </article>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Marketplace</p>
            <h2>Listings that name food, supplements or treatments ({openReviews.length} to check)</h2>
          </div>
        </div>
        <p className="muted">
          Already public: the seller confirmed they sell none of those things. If nobody acts, they stay.
        </p>
        <div className="data-table moderation-live-table moderation-with-action">
          <div className="table-row table-head">
            <span>Confirmed</span><span>Words found</span><span>Listing</span><span>Check</span><span>Listing status</span><span>Action</span>
          </div>
          {listingReviews.length ? listingReviews.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.confirmed_at)}</span>
              <span>{item.terms.join(", ") || "—"}</span>
              <span>{item.title}</span>
              <span>{item.status === "open" ? LISTING_REVIEW_LABELS.open : `${LISTING_REVIEW_LABELS[item.status]} · ${date(item.decided_at)} · ${item.decided_by_admin_id ?? "—"}`}</span>
              <span>{item.listing_status}</span>
              <span>
                <Link className="table-action-link" href={`/moderation/listing_reviews/${encodeURIComponent(item.id)}`}>
                  Open
                </Link>
              </span>
            </div>
          )) : <div className="table-empty">No listings to check.</div>}
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Marketplace</p>
            <h2>Live reports</h2>
          </div>
        </div>
        <div className="data-table moderation-live-table moderation-with-action">
          <div className="table-row table-head">
            <span>Created</span><span>Reason</span><span>Listing</span><span>Report</span><span>Listing status</span><span>Action</span>
          </div>
          {moderation.marketplace.length ? moderation.marketplace.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.created_at)}</span>
              <span>{item.reason}</span>
              <span>{item.listing?.title ?? item.listing_id}</span>
              <span>{item.status}</span>
              <span>{item.listing?.status ?? "missing"}</span>
              <span>
                <Link className="table-action-link" href={`/moderation/marketplace/${item.id}`}>
                  Open
                </Link>
              </span>
            </div>
          )) : <div className="table-empty">No marketplace reports.</div>}
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Marketplace messages</p>
            <h2>Reported conversations</h2>
          </div>
        </div>
        <div className="data-table moderation-live-table moderation-with-action">
          <div className="table-row table-head">
            <span>Created</span><span>Reason</span><span>Listing</span><span>Report</span><span>Action</span>
          </div>
          {moderation.marketplace_messages.length ? moderation.marketplace_messages.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.created_at)}</span>
              <span>{item.reason}</span>
              <span>{item.listing_title ?? "—"}</span>
              <span>{item.status}</span>
              <span>
                <Link className="table-action-link" href={`/moderation/marketplace_messages/${item.id}`}>
                  Open
                </Link>
              </span>
            </div>
          )) : <div className="table-empty">No reported conversations.</div>}
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Marketplace</p>
            <h2>People kept out of the Mercatino ({activeRestrictions.length} active)</h2>
          </div>
        </div>
        <p className="muted">
          They cannot publish or edit ads or write messages; they can still read and report.
          They see the reason in their language and the date, never the note.
        </p>
        <MarketplaceRestrictForm label="Keep this person out" />
        <div className="data-table moderation-live-table moderation-with-action">
          <div className="table-row table-head">
            <span>Since</span><span>User id</span><span>Reason</span><span>Note</span><span>Lifted</span><span>Action</span>
          </div>
          {restrictions.length ? restrictions.map((item) => (
            <div className="table-row" key={`${item.owner_id}-${item.created_at}`}>
              <span>{date(item.created_at)}</span>
              <span><Link className="table-action-link" href={`/users/${encodeURIComponent(item.owner_id)}`}>{item.owner_id}</Link></span>
              <span>{item.reason}</span>
              <span>{item.note ?? "—"}</span>
              <span>{date(item.lifted_at)}</span>
              <span>
                <Link className="table-action-link" href={`/users/${encodeURIComponent(item.owner_id)}#actions`}>Apri azioni →</Link>
              </span>
            </div>
          )) : <div className="table-empty">Nobody is kept out of the Mercatino.</div>}
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Chat</p>
            <h2>Response reports</h2>
          </div>
        </div>
        <div className="data-table chat-report-table moderation-with-action">
          <div className="table-row table-head">
            <span>Created</span><span>Reason</span><span>Status</span><span>Conversation</span><span>Action</span>
          </div>
          {moderation.chat.length ? moderation.chat.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.created_at)}</span>
              <span>{item.reason}</span>
              <span>{item.status}</span>
              <span><code>{item.conversation_id}</code></span>
              <span>
                <Link className="table-action-link" href={`/moderation/chat/${item.id}`}>
                  Open
                </Link>
              </span>
            </div>
          )) : <div className="table-empty">No chat response reports.</div>}
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Radar</p>
            <h2>User reports</h2>
          </div>
        </div>
        <div className="data-table radar-report-table moderation-with-action">
          <div className="table-row table-head">
            <span>Created</span><span>Kind</span><span>Status</span><span>Place</span><span>Votes</span><span>Target</span><span>Action</span>
          </div>
          {moderation.radar.length ? moderation.radar.map((item) => (
            <div className="table-row" key={item.id}>
              <span>{date(item.created_at)}</span>
              <span>{item.kind}</span>
              <span>{item.status}</span>
              <span>{item.name ?? item.place_type}</span>
              <span>{item.confirmations} / {item.denials}</span>
              <span>{item.target_source ?? "new place"}</span>
              <span>
                <Link className="table-action-link" href={`/moderation/radar/${item.id}`}>
                  Open
                </Link>
              </span>
            </div>
          )) : <div className="table-empty">No Radar reports.</div>}
        </div>
      </section>
    </AdminShell>
  );
}
