"use client";

import Link from "next/link";
import { useState } from "react";
import type { UserCase } from "../lib/admin-api";
import { UserActions } from "./user-actions";

export function ModerationCaseActions({ cases }: { cases: UserCase[] }) {
  const [selected, setSelected] = useState<string[]>([]);
  const chosen = cases.filter((item) =>
    selected.includes(`${item.queue}:${item.id}`),
  );
  const targets = [
    ...new Map(chosen.map((item) => [item.owner_id, item])).values(),
  ];
  return (
    <section className="panel users-panel">
      <h2>Interventi sugli utenti dai casi</h2>
      <p className="muted">
        Seleziona i casi ricevuti da verificare. Più casi della stessa persona
        producono un solo intervento; l’anteprima indica il caso collegato.
        Nessuna decisione è automatica.
      </p>
      <div className="moderation-case-selection">
        {cases.map((item) => (
          <label key={`${item.queue}:${item.id}`}>
            <input
              type="checkbox"
              checked={selected.includes(`${item.queue}:${item.id}`)}
              onChange={(event) =>
                setSelected((previous) =>
                  event.target.checked
                    ? [...previous, `${item.queue}:${item.id}`]
                    : previous.filter(
                        (value) => value !== `${item.queue}:${item.id}`,
                      ),
                )
              }
            />
            <Link
              className="table-action-link"
              href={`/moderation/${item.queue}/${encodeURIComponent(item.id)}`}
            >
              {item.queue} · {item.id}
            </Link>
            {" → "}
            <Link href={`/users/${encodeURIComponent(item.owner_id)}`}>
              Scheda utente
            </Link>
          </label>
        ))}
      </div>
      {!cases.length && (
        <p className="muted">
          Nessun caso del Mercatino con account disponibile.
        </p>
      )}
      {targets.length > 0 && (
        <UserActions key={selected.join(",")} cases={targets} />
      )}
    </section>
  );
}
