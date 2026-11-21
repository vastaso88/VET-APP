import { api } from "../../lib/api";
export const dynamic = "force-dynamic";
type Entry = { type: string; version: string; text: string; required: boolean };
export default async function Legal() {
  const response = await api("/legal/consents?lang=it", {}, false);
  const data = response.ok
    ? ((await response.json()) as { catalog: Record<string, Entry> })
    : null;
  return (
    <section className="narrow">
      <p className="eyebrow">INFORMAZIONI SUL SERVIZIO</p>
      <h1>Privacy e condizioni</h1>
      <p>
        Questi sono i testi attualmente disponibili nell’app. L’informativa
        completa è in preparazione.
      </p>
      {data ? (
        Object.entries(data.catalog).map(([key, entry]) => (
          <article key={key}>
            <h2 style={{ fontSize: 28 }}>
              {(
                {
                  terms_of_service: "Termini del servizio",
                  privacy_policy: "Privacy",
                  marketing_email: "Email di marketing",
                  analytics: "Statistiche",
                  diagnostics: "Diagnostica",
                  contribution_rules: "Regole dei contributi",
                } as Record<string, string>
              )[key] ?? key}
            </h2>
            <p>{entry.text}</p>
            <p className="small">Versione {entry.version}</p>
          </article>
        ))
      ) : (
        <p>I documenti non sono disponibili. Riprova dall’app.</p>
      )}
    </section>
  );
}
