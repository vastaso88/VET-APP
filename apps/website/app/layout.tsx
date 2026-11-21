import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";
export const metadata: Metadata = {
  title: {
    default: "Quokka — La vita insieme, più semplice",
    template: "%s | Quokka",
  },
  description:
    "Profili dei tuoi animali, promemoria, assistente e servizi vicini. Scopri Quokka e gestisci il tuo account.",
};
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="it">
      <body>
        <a className="skip" href="#content">
          Vai al contenuto
        </a>
        <header>
          <Link className="brand" href="/" aria-label="Quokka, pagina iniziale">
            <span aria-hidden="true">q.</span> quokka
          </Link>
          <nav aria-label="Navigazione principale">
            <Link href="/#funzioni">L’app</Link>
            <Link href="/account">
              Area personale <span aria-hidden="true">↗</span>
            </Link>
          </nav>
        </header>
        <main id="content">{children}</main>
        <footer>
          <Link className="brand" href="/">
            quokka
          </Link>
          <p>Un posto per prenderti cura di chi ti sta vicino.</p>
          <Link href="/legal">Privacy e condizioni</Link>
          <Link href="/delete-account">Elimina account</Link>
        </footer>
      </body>
    </html>
  );
}
