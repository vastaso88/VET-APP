export default function AdminLoading() {
  return (
    <main style={{ padding: "32px", maxWidth: 1100, margin: "0 auto" }} aria-live="polite">
      <p style={{ color: "#66717f", fontSize: 13 }}>VET APP · Admin operations</p>
      <h2 style={{ fontSize: 20, marginBottom: 20 }}>Caricamento dati…</h2>
      <div style={{ display: "grid", gap: 12 }}>
        <div style={{ height: 64, borderRadius: 10, background: "#e8edf0" }} />
        <div style={{ height: 200, borderRadius: 10, background: "#e8edf0" }} />
      </div>
    </main>
  );
}
