import Link from "next/link";
import type { ReactNode } from "react";

import { requireAdminSession } from "../lib/admin-api";
import { logout } from "../app/login/actions";

const sections = [
  { href: "/", label: "Overview" },
  { href: "/moderation", label: "Moderation" },
  { href: "/data/geographic", label: "Geographic data" },
  { href: "/data/scientific", label: "Scientific data" },
  { href: "/jobs", label: "Ingestion jobs" },
];

export async function AdminShell({
  title,
  eyebrow,
  children,
}: {
  title: string;
  eyebrow: string;
  children: ReactNode;
}) {
  const admin = await requireAdminSession();

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">V</div>
          <div>
            <strong>VET APP</strong>
            <span>Admin operations</span>
          </div>
        </div>

        <nav className="sidebar-nav" aria-label="Admin navigation">
          {sections.map((item) => (
            <Link key={item.href} href={item.href}>
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="sidebar-foot">
          <span className="status-dot" />
          Internal backoffice
        </div>
      </aside>

      <main className="main-area">
        <header className="topbar">
          <div>
            <p className="eyebrow">{eyebrow}</p>
            <h1>{title}</h1>
          </div>
          <div className="admin-account">
            <span>{admin.email}</span>
            <form action={logout}>
              <button className="ghost-button" type="submit">Logout</button>
            </form>
          </div>
        </header>
        <section className="content">{children}</section>
      </main>
    </div>
  );
}
