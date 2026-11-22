"use client";

export default function AdminError({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="login-page">
      <section className="login-card" role="alert">
        <h1>Connessione temporaneamente non disponibile</h1>
        <p>
          Non ti abbiamo disconnesso. La verifica amministrativa o il backend
          non hanno risposto correttamente. Puoi riprovare senza reinserire
          le credenziali.
        </p>
        <button className="primary-button" type="button" onClick={() => reset()}>
          Riprova
        </button>
      </section>
    </main>
  );
}
