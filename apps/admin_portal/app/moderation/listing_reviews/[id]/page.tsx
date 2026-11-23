import Link from "next/link";

import { AdminShell } from "../../../../components/admin-shell";
import { getListingReview, LISTING_REVIEW_LABELS, type HighlightedPiece } from "../../../../lib/admin-api";
import { decideListingReviewAction } from "../../actions";

function date(value: string | null): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("it-IT", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function Highlighted({ pieces }: { pieces: HighlightedPiece[] }) {
  if (!pieces.length) return <>—</>;
  return <>{pieces.map((piece, index) => piece.hit ? <mark key={index}>{piece.text}</mark> : <span key={index}>{piece.text}</span>)}</>;
}

export default async function ListingReviewPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ conflict?: string }>;
}) {
  const { id } = await params;
  const { conflict } = await searchParams;
  const review = await getListingReview(id);

  if (!review) {
    return (
      <AdminShell title="Listing check" eyebrow="Marketplace">
        <div><Link className="table-action-link" href="/moderation">← Back to moderation</Link></div>
        <section className="panel">
          <h2>Not found</h2>
          <p className="muted">The listing was deleted, or the backend update is not live yet.</p>
        </section>
      </AdminShell>
    );
  }

  const visible = review.listing_status === "active" || review.listing_status === "reserved";
  // The photos come from the seller: only web addresses become links.
  const photos = review.photo_urls.filter((url) => url.startsWith("https://"));

  return (
    <AdminShell title="Listing check" eyebrow="Marketplace">
      <div>
        <Link className="table-action-link" href="/moderation">← Back to moderation</Link>
        <Link className="table-action-link" href={`/users/${encodeURIComponent(review.owner_id)}`}> · Scheda venditore →</Link>
      </div>

      {conflict ? (
        <section className="panel">
          <p className="muted">
            Nothing was decided: the listing changed, or was decided, after you opened it. Read it again below.
          </p>
        </section>
      ) : null}

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">{review.notices.join(", ")}</p>
            <h2><Highlighted pieces={review.highlighted_title} /></h2>
          </div>
          <span className="tag">{LISTING_REVIEW_LABELS[review.status]}</span>
        </div>
        <div className="detail-grid">
          <div><span>Listing status</span><strong>{review.listing_status}</strong></div>
          <div><span>Category</span><strong>{review.category}</strong></div>
          <div><span>Price cents</span><strong>{review.price_cents ?? "gift"}</strong></div>
          <div><span>City</span><strong>{review.city_label ?? "—"}</strong></div>
          <div><span>Words found</span><strong>{review.terms.join(", ") || "—"}</strong></div>
          <div><span>Confirmed by the seller</span><strong>{date(review.confirmed_at)} (text {review.confirmation_version})</strong></div>
          <div><span>Decided</span><strong>{date(review.decided_at)}</strong></div>
          <div><span>Decided by</span><strong>{review.decided_by_admin_id ?? "—"}</strong></div>
          <div><span>Reason told to the seller</span><strong>{review.removal_reason ?? "—"}</strong></div>
          <div><span>Internal note</span><strong>{review.note ?? "—"}</strong></div>
        </div>
        <div className="detail-copy">
          <h3>Description</h3>
          <p><Highlighted pieces={review.highlighted_description} /></p>
        </div>
        <div className="detail-copy">
          <h3>Photos</h3>
          <div className="compact-list">
            {photos.length ? photos.map((url, index) => (
              <span key={url}><a className="table-action-link" href={url} target="_blank" rel="noreferrer">Photo {index + 1} ↗</a></span>
            )) : <span>No photos.</span>}
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Admin action</p>
            <h2>Decide</h2>
          </div>
        </div>
        <p className="muted">
          The listing is already public; if nobody acts it stays. Taking it down shows the seller the reason, the
          date and how to ask for a review, never your name or the note. A listing that really sells food,
          supplements or treatments must be taken down.
        </p>
        {review.status === "superseded" ? (
          <p className="muted">The seller changed the listing: the newer check is in the queue.</p>
        ) : (
          <form action={decideListingReviewAction} className="moderation-action-form">
            <input type="hidden" name="review_id" value={id} />
            <label>
              Reason told to the seller (needed to take it down)
              <select name="reason" defaultValue="">
                <option value="">—</option>
                <option value="food">Food or feed</option>
                <option value="supplement">Supplements</option>
                <option value="medicine">Medicines or products with active ingredients</option>
                <option value="other">Another breach of the marketplace rules</option>
              </select>
            </label>
            <label>
              Internal note
              <input name="note" maxLength={1000} placeholder="Optional, never shown to the seller" />
            </label>
            <div className="form-actions">
              {review.status === "open" ? <button className="primary-button" name="outcome" value="checked">Checked, leave it</button> : null}
              {visible ? <button className="danger-button" name="outcome" value="removed">Take it down</button> : null}
              {review.status === "removed" && review.listing_status === "removed_policy" ? <button className="ghost-button" name="outcome" value="restored">Put it back (review accepted)</button> : null}
            </div>
          </form>
        )}
      </section>
    </AdminShell>
  );
}
