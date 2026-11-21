"use client";
export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <section className="narrow">
      <h1>Ci riproviamo?</h1>
      <p role="alert">Il servizio non risponde. Riprova tra poco.</p>
      <button onClick={reset}>Riprova</button>
      <p>
        <a href="/login">Torna all’accesso</a>
      </p>
    </section>
  );
}
