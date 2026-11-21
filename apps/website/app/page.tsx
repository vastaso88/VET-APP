import Link from "next/link";
import { StoreDownloads } from "./components/store-downloads";
export default function Home() {
  const ios = storeUrl(process.env.QUOKKA_IOS_STORE_URL, "apps.apple.com");
  const android = storeUrl(
    process.env.QUOKKA_ANDROID_STORE_URL,
    "play.google.com",
  );
  return (
    <>
      <section className="hero">
        <div>
          <p className="eyebrow">IL TUO ANIMALE. LA VOSTRA QUOTIDIANITÀ.</p>
          <h1>
            Le piccole cose.
            <br />
            <em>La sua vita intera.</em>
          </h1>
          <p className="intro">
            Documenti, appuntamenti e domande di ogni giorno. Quokka ti aiuta a
            tenere insieme ciò che conta per i tuoi animali.
          </p>
          <StoreDownloads ios={ios} android={android} />
          <div className="actions">
            <Link className="text-link" href="/login">
              Hai già un account? Accedi <span aria-hidden="true">↗</span>
            </Link>
            <a className="text-link" href="#funzioni">
              Conosci Quokka ↓
            </a>
          </div>
          <p className="small">
            Download gratuito. Account necessario per usare l’app.
            <br />
            La durata della prova è indicata nella tua area personale.
          </p>
        </div>
        <div
          className="illustration"
          role="img"
          aria-label="Illustrazione di un cane e un gatto insieme"
        >
          <svg viewBox="0 0 440 450" aria-hidden="true">
            <path fill="#e9e4d8" d="M20 270Q80 170 220 200T420 285V430H20Z" />
            <ellipse cx="236" cy="405" rx="170" ry="15" fill="#d9d2c3" />
            <path
              d="M100 388V230Q85 160 130 115L152 65L188 114Q250 128 252 210L270 385Z"
              fill="#b99a76"
            />
            <path
              d="M135 115Q88 85 73 135L93 235Q115 255 135 207Z"
              fill="#715948"
            />
            <path
              d="M160 252Q145 340 171 389H230Q244 319 209 255Z"
              fill="#eee7d8"
            />
            <circle cx="180" cy="167" r="6" fill="#302e28" />
            <path d="M214 183q25-12 24 5q-15 23-24-5" fill="#302e28" />
            <path
              d="M264 393Q245 300 273 248L262 188L304 218L337 183L345 246Q380 320 359 395Z"
              fill="#535b50"
            />
            <path
              d="M339 367Q414 323 410 378Q402 414 351 395"
              fill="none"
              stroke="#535b50"
              strokeWidth="23"
              strokeLinecap="round"
            />
            <path
              d="M286 263h10m28 0h10"
              stroke="#f5f0e6"
              strokeWidth="5"
              strokeLinecap="round"
            />
            <path d="m306 280 9 0-4 7Z" fill="#dfc1aa" />
            <path d="M280 395v-62m47 62v-62" stroke="#424b41" strokeWidth="6" />
            <path
              d="M40 155q-18-50 15-58q22 8 4 57m313-39q18-49 36-28q4 24-34 37"
              fill="#c8cebb"
            />
          </svg>
          <span className="illustration-caption">OGNI GIORNO, INSIEME.</span>
        </div>
      </section>
      <section id="funzioni">
        <p className="eyebrow">MENO COSE SPARSE. PIÙ ATTENZIONE.</p>
        <h2>
          Una quotidianità
          <br />
          con tutto al suo posto.
        </h2>
        <div className="features">
          {[
            [
              "01",
              "La sua storia",
              "Un profilo per ogni animale, con informazioni e documenti da ritrovare quando servono.",
            ],
            [
              "02",
              "Le cose da ricordare",
              "Promemoria e appuntamenti per organizzare le attenzioni di ogni giorno.",
            ],
            [
              "03",
              "Una domanda alla volta",
              "Un assistente con cui orientarti tra le domande sui tuoi animali. Non sostituisce il veterinario.",
            ],
            [
              "04",
              "Vicino a voi",
              "Cerca servizi per animali nella tua zona e consulta le informazioni disponibili.",
            ],
          ].map(([n, title, body]) => (
            <article key={n}>
              <span className="number">{n}</span>
              <h3>{title}</h3>
              <p>{body}</p>
            </article>
          ))}
        </div>
      </section>
      <section className="start">
        <p className="eyebrow">IL PRIMO PASSO È CONOSCERSI.</p>
        <h2>
          Il tuo account.
          <br />
          Anche fuori dall’app.
        </h2>
        <p>
          Usa le stesse credenziali dell’app per vedere la prova gratuita, il
          piano e consultare lo stato del tuo account. Gli abbonamenti si
          attivano direttamente nell’app tramite lo store del tuo dispositivo.
        </p>
        <Link className="button" href="/login">
          Entra nell’area personale ↗
        </Link>
      </section>
    </>
  );
}
function storeUrl(value: string | undefined, host: string) {
  try {
    const u = new URL(value ?? "");
    return u.protocol === "https:" &&
      u.hostname === host &&
      !u.username &&
      !u.password &&
      !u.port
      ? u.href
      : null;
  } catch {
    return null;
  }
}
