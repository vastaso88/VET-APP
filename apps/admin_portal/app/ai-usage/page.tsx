import { AdminShell } from "../../components/admin-shell";
import { getAdminLlmUsage, type LlmBudgetState, type LlmUsageTotals } from "../../lib/admin-api";
import {
  chartGeometry,
  formatCount,
  formatDay,
  formatEur,
  formatPercent,
  formatUsd,
} from "../../lib/llm-usage-format";

// The exact bill is Anthropic's: this page adds up our own counts.
const CONSOLE_COST_URL = "https://platform.claude.com/cost";

const STATE_TEXT: Record<LlmBudgetState, { label: string; detail: string }> = {
  ok: { label: "Nei limiti", detail: "Claude risponde a tutti." },
  reserve: {
    label: "Riserva",
    detail: "Oltre la soglia di riserva del tetto: Sonnet è spento, Haiku risponde ancora.",
  },
  exhausted: {
    label: "Tetto raggiunto",
    detail: "Claude è fermo fino a mezzanotte UTC: risponde la riserva Groq.",
  },
};

/** The month's credits: the colour only, the limit itself is in the Console. */
function creditsState(share: number): LlmBudgetState {
  if (share >= 1) return "exhausted";
  if (share >= 0.8) return "reserve";
  return "ok";
}

function Meter({ share, state }: { share: number; state: LlmBudgetState }) {
  const width = Math.min(100, Math.max(0, share * 100));
  return (
    <div
      className={`usage-meter usage-meter-${state}`}
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(width)}
    >
      <span style={{ width: `${width}%` }} />
    </div>
  );
}

function cost(totals: LlmUsageTotals, paid: boolean): string {
  return paid ? formatEur(totals.eur) : "gratis";
}

export default async function AiUsagePage() {
  const usage = await getAdminLlmUsage();

  if (usage === null) {
    return (
      <AdminShell title="Consumi IA" eyebrow="Costi">
        <section className="panel">
          <p className="eyebrow">Non disponibile</p>
          <h2>Il registro dei consumi non risponde</h2>
          <p className="muted">
            Riprova tra poco. Il conto esatto è sempre nella{" "}
            <a href={CONSOLE_COST_URL} target="_blank" rel="noopener noreferrer">
              Console Anthropic
            </a>
            .
          </p>
        </section>
      </AdminShell>
    );
  }

  const { today, month } = usage;
  const state = STATE_TEXT[today.state];
  const chart = chartGeometry(usage.daily, today.cap_eur);
  const first = usage.daily[0];
  const last = usage.daily[usage.daily.length - 1];

  return (
    <AdminShell title="Consumi IA" eyebrow="Costi">
      <div className="metric-grid">
        <article className="metric-card">
          <span>Spesa di oggi</span>
          <strong>{formatEur(today.spent_eur)}</strong>
          <small>
            {today.cap_eur === null
              ? "senza tetto giornaliero"
              : `tetto ${formatEur(today.cap_eur)} · ${formatPercent(today.share_of_cap)}`}
            {" · "}
            {formatUsd(today.spent_usd)}
          </small>
        </article>
        <article className="metric-card">
          <span>Spesa del mese</span>
          <strong>{formatUsd(month.spent_usd)}</strong>
          <small>
            {formatEur(month.spent_eur)} · {formatPercent(month.share_of_credits)} dei{" "}
            {formatUsd(month.credits_usd)} di crediti
          </small>
        </article>
        <article className="metric-card">
          <span>Risposte Sonnet oggi</span>
          <strong>{formatCount(usage.sonnet_answers_today)}</strong>
          <small>oltre il tetto del piano risponde Haiku</small>
        </article>
        <article className="metric-card">
          <span>Riserva Groq oggi</span>
          <strong>{formatCount(usage.reserve_calls_today)}</strong>
          <small>
            chiamate · {formatCount(usage.failed_calls_today)} fallite oggi,{" "}
            {formatCount(usage.failed_calls_month)} nel mese
          </small>
        </article>
      </div>

      <div className="two-column">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Tetto giornaliero</p>
              <h2>Oggi, {formatDay(today.date)}</h2>
            </div>
            <span className={`usage-state usage-state-${today.state}`}>{state.label}</span>
          </div>
          <Meter share={today.share_of_cap ?? 0} state={today.state} />
          <p className="muted">{state.detail}</p>
        </section>

        <section className="panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Crediti del mese</p>
              <h2>
                {month.month}, giorno {month.days_elapsed} di {month.days_in_month}
              </h2>
            </div>
          </div>
          <Meter share={month.share_of_credits} state={creditsState(month.share_of_credits)} />
          <p className="muted">
            Stima a fine mese, a questo ritmo: {formatUsd(month.projected_usd)} su{" "}
            {formatUsd(month.credits_usd)}.
          </p>
        </section>
      </div>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Per modello</p>
            <h2>Chiamate, token e costo</h2>
          </div>
        </div>
        <div className="data-table usage-table">
          <div className="table-row table-head">
            <span>Modello</span>
            <span>Oggi: chiamate</span>
            <span>Oggi: token</span>
            <span>Oggi: costo</span>
            <span>Mese: chiamate</span>
            <span>Mese: token</span>
            <span>Mese: costo</span>
          </div>
          {usage.models.length ? (
            usage.models.map((model) => (
              <div className="table-row" key={model.model}>
                <span>
                  {model.label} <span className="tag">{model.paid ? "Claude" : "Groq"}</span>
                </span>
                <span>{formatCount(model.today.calls)}</span>
                <span>{formatCount(model.today.total_tokens)}</span>
                <span>{cost(model.today, model.paid)}</span>
                <span>{formatCount(model.month.calls)}</span>
                <span>{formatCount(model.month.total_tokens)}</span>
                <span>{cost(model.month, model.paid)}</span>
              </div>
            ))
          ) : (
            <div className="table-empty">Nessuna chiamata registrata nel mese.</div>
          )}
        </div>
      </section>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Ultimi 30 giorni</p>
            <h2>Spesa al giorno</h2>
          </div>
        </div>
        <svg
          className="usage-chart"
          viewBox={`0 0 ${chart.width} ${chart.height}`}
          role="img"
          aria-label="Spesa giornaliera degli ultimi 30 giorni, in euro"
        >
          <line
            className="usage-axis-line"
            x1={chart.plot.left}
            x2={chart.plot.right}
            y1={chart.plot.bottom}
            y2={chart.plot.bottom}
          />
          <text className="usage-axis" x={chart.plot.left - 6} y={chart.plot.bottom} textAnchor="end">
            0
          </text>
          <text
            className="usage-axis"
            x={chart.plot.left - 6}
            y={chart.plot.top + 8}
            textAnchor="end"
          >
            {formatEur(chart.scaleMax)}
          </text>
          {chart.bars.map((bar) => (
            <rect
              key={bar.date}
              className={bar.over ? "usage-bar usage-bar-over" : "usage-bar"}
              x={bar.x}
              y={bar.y}
              width={bar.width}
              height={bar.height}
            >
              <title>{bar.tip}</title>
            </rect>
          ))}
          {chart.capY !== null ? (
            <line
              className="usage-cap-line"
              x1={chart.plot.left}
              x2={chart.plot.right}
              y1={chart.capY}
              y2={chart.capY}
            />
          ) : null}
          {first && last ? (
            <>
              <text className="usage-axis" x={chart.plot.left} y={chart.height - 6}>
                {formatDay(first.date)}
              </text>
              <text className="usage-axis" x={chart.plot.right} y={chart.height - 6} textAnchor="end">
                {formatDay(last.date)}
              </text>
            </>
          ) : null}
        </svg>
        <p className="muted">
          {today.cap_eur === null
            ? "Le barre sono la spesa di ogni giorno."
            : "Le barre sono la spesa di ogni giorno; la linea tratteggiata è il tetto giornaliero, in rosso i giorni che l'hanno raggiunto."}
        </p>
      </section>

      <section className="panel">
        <p className="eyebrow">Come leggere questi numeri</p>
        <p className="muted">
          Sono stime calcolate dai nostri conteggi, non il conto: l&apos;importo esatto è nella{" "}
          <a href={CONSOLE_COST_URL} target="_blank" rel="noopener noreferrer">
            Console Anthropic
          </a>{" "}
          ({CONSOLE_COST_URL}). I giorni sono giorni UTC. Una risposta della chat può richiedere
          più chiamate (controllo d&apos;urgenza, parole chiave, risposta), quindi le chiamate non
          sono le risposte; per Sonnet, che scrive solo risposte, coincidono. Costi calcolati con
          1 € = {usage.usd_per_eur.toLocaleString("it-IT")} $ e inferenza{" "}
          {usage.inference_geo === "us" ? "solo USA (+10%)" : "globale"}; i giorni passati usano
          il cambio e la regione di oggi.
        </p>
      </section>
    </AdminShell>
  );
}
