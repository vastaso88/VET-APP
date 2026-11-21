import type { Metadata } from "next";
import { authenticate } from "../actions";
export const metadata: Metadata = {
  title: "Accedi",
  robots: { index: false, follow: false },
};
const messages: Record<string, string> = {
  invalid: "Accesso non riuscito. Controlla le credenziali.",
  unavailable: "Il servizio non è disponibile. Riprova tra poco.",
  confirm:
    "Controlla la tua email per confermare la registrazione, poi accedi.",
  expired: "La sessione è terminata. Accedi di nuovo.",
};
export default async function Login({
  searchParams,
}: {
  searchParams: Promise<{ notice?: string }>;
}) {
  const { notice } = await searchParams;
  return (
    <section className="narrow">
      <p className="eyebrow">BENTORNATO, O BENVENUTO.</p>
      <h1>Il tuo spazio.</h1>
      <p>
        Accedi con l’email e la password che usi nell’app Quokka. Se non hai un
        account, crealo dall’app.
      </p>
      {notice && messages[notice] && (
        <p role="status" className="notice">
          {messages[notice]}
        </p>
      )}
      <form action={authenticate} className="form">
        <label>
          Email
          <input
            type="email"
            name="email"
            autoComplete="email"
            maxLength={254}
            required
          />
        </label>
        <label>
          Password
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            maxLength={72}
            required
          />
        </label>
        <button>Accedi ↗</button>
      </form>
      <p className="small">
        La prova non richiede una carta. Nessun addebito avviene registrandoti.
        Puoi recuperare la password dall’app.
      </p>
    </section>
  );
}
