import { restrictMarketplaceUser } from "../app/moderation/actions";

export const RESTRICTION_REASONS = [
  ["spam", "Spam"],
  ["scam", "Scam"],
  ["harassment", "Harassment"],
  ["prohibited_items", "Prohibited items"],
  ["other", "Other rule breach"],
] as const;

/**
 * Keeps one person out of the Mercatino (no new ads, no edits, no messages).
 * The person sees the reason in their own language and the date; the note stays
 * in the portal.
 */
export function MarketplaceRestrictForm({
  ownerId,
  label,
}: {
  ownerId?: string | null;
  label: string;
}) {
  return (
    <form action={restrictMarketplaceUser} className="moderation-action-form">
      {ownerId ? (
        <input type="hidden" name="owner_id" value={ownerId} />
      ) : (
        <label>
          User id
          <input name="owner_id" required maxLength={100} placeholder="Account id" />
        </label>
      )}
      <label>
        Reason
        <select name="reason" defaultValue="spam">
          {RESTRICTION_REASONS.map(([value, text]) => (
            <option key={value} value={value}>{text}</option>
          ))}
        </select>
      </label>
      <label>
        Note (team only)
        <input name="note" maxLength={1000} placeholder="Optional, never shown to the person" />
      </label>
      <div className="form-actions">
        <button className="danger-button" type="submit">{label}</button>
      </div>
    </form>
  );
}
