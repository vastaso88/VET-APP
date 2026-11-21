"use client";

import Link from "next/link";
import { useState } from "react";
import type { UserAccount } from "../lib/admin-api";
import { accessLabels, countryName, userDate } from "../lib/user-format";
import { UserActions } from "./user-actions";

export function UsersTable({
  users,
  q,
  country,
}: {
  users: UserAccount[];
  q: string;
  country: string;
}) {
  const [selected, setSelected] = useState<string[]>([]);
  const [allResults, setAllResults] = useState(false);
  function toggle(id: string) {
    setSelected((previous) =>
      previous.includes(id)
        ? previous.filter((value) => value !== id)
        : [...previous, id],
    );
  }
  return (
    <>
      <div className="users-selection">
        <label>
          <input
            type="checkbox"
            checked={users.length > 0 && selected.length === users.length}
            disabled={allResults || users.length === 0}
            onChange={(event) =>
              setSelected(
                event.target.checked ? users.map((user) => user.id) : [],
              )
            }
          />{" "}
          Seleziona questa pagina
        </label>
        <label>
          <input
            type="checkbox"
            checked={allResults}
            onChange={(event) => {
              setAllResults(event.target.checked);
              setSelected([]);
            }}
          />{" "}
          Tutti i risultati dei filtri (massimo 100)
        </label>
      </div>
      <div className="users-table-scroll">
        <table className="users-table">
          <caption className="sr-only">
            Account, nazione, iscrizione, accesso e piano
          </caption>
          <thead>
            <tr>
              {[
                "Selezione",
                "Utente",
                "Nazione",
                "Iscritto dal",
                "Ultimo login",
                "Account",
                "Piano e accesso",
                "Fine prova",
              ].map((label) => (
                <th scope="col" key={label}>
                  {label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.id}>
                <td>
                  <input
                    type="checkbox"
                    aria-label={`Seleziona ${user.email ?? user.id}`}
                    checked={allResults || selected.includes(user.id)}
                    disabled={allResults}
                    onChange={() => toggle(user.id)}
                  />
                </td>
                <td>
                  <Link
                    className="table-action-link"
                    href={`/users/${encodeURIComponent(user.id)}`}
                  >
                    {user.email ?? "Senza email"}
                  </Link>
                  <small>{user.id}</small>
                </td>
                <td>
                  {countryName(user.location?.country_code)}
                  {user.location?.country_code && (
                    <small>
                      Residenza ·{" "}
                      {user.location.city ?? "Città non disponibile"}
                    </small>
                  )}
                </td>
                <td>{userDate(user.created_at)}</td>
                <td>{userDate(user.last_sign_in_at)}</td>
                <td>
                  {user.banned_until
                    ? `Sospeso fino al ${userDate(user.banned_until)}`
                    : "Non sospeso"}
                  <small>
                    {user.email_verified
                      ? "Email verificata"
                      : "Email non verificata"}
                  </small>
                </td>
                <td>
                  <strong>
                    {user.effective_plan?.toUpperCase() ?? "Nessun piano"}
                  </strong>
                  <small>{accessLabels[user.access]}</small>
                </td>
                <td>{userDate(user.trial_ends_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!users.length && (
          <p className="table-empty">Nessun utente corrisponde ai filtri.</p>
        )}
      </div>
      {(allResults || selected.length > 0) && (
        <UserActions
          key={`${allResults}:${selected.join(",")}`}
          ownerIds={selected}
          allResults={allResults}
          filter={{ q, country }}
        />
      )}
    </>
  );
}
