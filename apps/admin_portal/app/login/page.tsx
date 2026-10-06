import { redirect } from "next/navigation";

import { getAdminSession } from "../../lib/admin-api";
import { login } from "./actions";

const messages: Record<string, string> = {
  missing: "Inserisci email e password.",
  invalid: "Credenziali non valide.",
  forbidden: "Questo account non è autorizzato ad accedere al backoffice.",
  "not-configured": "L'accesso admin non è ancora configurato sul backend.",
  backend: "Backend non raggiungibile. Controlla VET_API_BASE_URL e il deploy API.",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const session = await getAdminSession();
  if (session) redirect("/");

  const params = await searchParams;
  const message = params.error ? messages[params.error] : null;

  return (
    <main className="login-page">
      <section className="login-card">
        <div className="brand login-brand">
          <div className="brand-mark">V</div>
          <div>
            <strong>VET APP</strong>
            <span>Admin operations</span>
          </div>
        </div>

        <div className="login-copy">
          <p className="eyebrow">Internal backoffice</p>
          <h1>Accesso amministratore</h1>
          <p>
            Usa un account Supabase autorizzato come admin o developer.
          </p>
        </div>

        {message ? <div className="login-error">{message}</div> : null}

        <form action={login} className="login-form">
          <label>
            Email
            <input name="email" type="email" autoComplete="email" required />
          </label>
          <label>
            Password
            <input name="password" type="password" autoComplete="current-password" required />
          </label>
          <button className="primary-button" type="submit">Accedi</button>
        </form>
      </section>
    </main>
  );
}
