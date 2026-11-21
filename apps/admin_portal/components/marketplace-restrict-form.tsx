"use client";

import { useState } from "react";
import type { UserCase } from "../lib/admin-api";
import { UserActions } from "./user-actions";

export function MarketplaceRestrictForm({
  ownerId,
  label,
  caseRef,
}: {
  ownerId?: string | null;
  label: string;
  caseRef?: UserCase;
}) {
  const [manualId, setManualId] = useState("");
  const target = ownerId || manualId.trim();
  return (
    <div>
      <h4>{label}</h4>
      {!ownerId && (
        <label>
          ID utente{" "}
          <input
            maxLength={100}
            value={manualId}
            onChange={(event) => setManualId(event.target.value)}
          />
        </label>
      )}
      {target && (
        <UserActions
          key={target}
          ownerIds={caseRef ? [] : [target]}
          cases={caseRef ? [caseRef] : []}
        />
      )}
    </div>
  );
}
