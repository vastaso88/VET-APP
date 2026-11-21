"use client";

import { useState } from "react";
import Link from "next/link";
import type { UserDetail } from "../lib/admin-api";
import { actionLabels, userDate } from "../lib/user-format";

export function UserTimeline({
  actions,
  logins,
  moderation,
}: Pick<UserDetail, "actions" | "logins" | "moderation">) {
  const [kind, setKind] = useState("");
  const events = [
    ...(logins ?? []).map((item) => ({
      id: `login:${item.occurred_at}`,
      at: item.occurred_at,
      kind: "login",
      label: "Login riuscito",
      detail: "Autenticazione Supabase",
      href: null as string | null,
    })),
    ...(actions ?? []).map((item) => ({
      id: item.id,
      at: item.created_at,
      kind: "admin",
      label:
        actionLabels[item.action as keyof typeof actionLabels] ?? item.action,
      detail: `${item.note} · ${item.changed ? "applicato" : "nessuna modifica"} · admin ${item.admin_id}${item.expires_at ? ` · scadenza ${userDate(item.expires_at)}` : ""}`,
      href:
        item.case_queue && item.case_id
          ? `/moderation/${item.case_queue}/${encodeURIComponent(item.case_id)}`
          : null,
    })),
    ...(moderation?.events ?? []).flatMap((item) => [
      {
        id: `report:${item.queue}:${item.id}:${item.direction}`,
        at: item.created_at,
        kind: "moderation",
        label:
          item.direction === "received"
            ? "Segnalazione ricevuta"
            : "Segnalazione inviata",
        detail: `${item.queue} · ${item.reason} · stato attuale: ${item.status}`,
        href: `/moderation/${item.queue}/${encodeURIComponent(item.id)}`,
      },
      ...(item.resolved_at
        ? [
            {
              id: `decision:${item.queue}:${item.id}:${item.direction}`,
              at: item.resolved_at,
              kind: "moderation",
              label: "Decisione di moderazione",
              detail: `${item.resolution_action ?? item.status} · admin ${item.resolved_by_admin_id ?? "non registrato"}`,
              href: `/moderation/${item.queue}/${encodeURIComponent(item.id)}`,
            },
          ]
        : []),
    ]),
  ].sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());
  const filtered = events.filter((event) => !kind || event.kind === kind);
  return (
    <>
      <label>
        Tipo di evento{" "}
        <select value={kind} onChange={(event) => setKind(event.target.value)}>
          <option value="">Tutti</option>
          <option value="login">Login</option>
          <option value="moderation">Moderazione</option>
          <option value="admin">Interventi amministrativi</option>
        </select>
      </label>
      <ol className="user-timeline">
        {filtered.map((event) => (
          <li key={event.id}>
            <small>{userDate(event.at)}</small>
            <strong>{event.label}</strong>
            <p>{event.detail}</p>
            {event.href && (
              <Link className="table-action-link" href={event.href}>
                Apri caso →
              </Link>
            )}
          </li>
        ))}
      </ol>
      {!filtered.length && (
        <p className="muted">Nessun evento disponibile per questo filtro.</p>
      )}
    </>
  );
}
