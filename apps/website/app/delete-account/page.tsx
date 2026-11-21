import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Elimina il tuo account Quokka",
  description: "Come richiedere la cancellazione dell’account Quokka e dei dati, anche senza l’app.",
};

export default function DeleteAccount() {
  return (
    <section className="narrow">
      <p className="eyebrow">ACCOUNT E DATI PERSONALI</p>
      <h1>Elimina il tuo account Quokka</h1>
      <p>Puoi richiedere la cancellazione anche se hai disinstallato l’app o non riesci ad accedere.</p>
      <h2>Senza l’app</h2>
      <p>
        Scrivi a <a href="mailto:quokkaapp26@gmail.com?subject=Eliminazione%20account%20Quokka">quokkaapp26@gmail.com</a>
        {" "}con oggetto «Eliminazione account Quokka», preferibilmente dall’indirizzo associato
        all’account. Se non puoi usarlo, indica l’indirizzo dell’account nella richiesta:
        l’assistenza ti aiuterà a verificarne la titolarità. Non inviare password, documenti
        veterinari o dati di pagamento.
      </p>
      <p>
        Chiedi la cancellazione dell’account e dei dati associati. L’invio dell’email apre
        una richiesta all’assistenza: non cancella automaticamente l’account. Prima di
        procedere, verifichiamo che la richiesta provenga dal titolare.
      </p>
      <h2>Dall’app</h2>
      <p>
        Apri Impostazioni → Account → Elimina account, scegli «Elimina» e segui le conferme.
        La schermata indica l’eventuale periodo per cambiare idea e la data di cancellazione.
        Mettere l’account in pausa non equivale a eliminarlo.
      </p>
      <h2>Quali dati vengono cancellati</h2>
      <p>
        La cancellazione riguarda l’account e i dati associati: profili degli animali, chat,
        promemoria, passeggiate, foto e video, referti e documenti, misurazioni, consensi,
        posizione salvata e annunci del mercatino. Scarica prima una copia dei dati che vuoi
        conservare. L’operazione completata non è reversibile.
      </p>
      <p>
        Possono restare i dati che dobbiamo conservare per obblighi di legge e una prova
        della cancellazione senza nome né email. Chiedi all’assistenza quali eccezioni e
        tempi si applicano al tuo account; consulta anche <Link href="/legal">l’informativa privacy</Link>.
      </p>
      <h2>Se hai un abbonamento</h2>
      <p>
        La cancellazione dell’account non disattiva automaticamente il rinnovo dello store.
        Puoi gestirlo separatamente in <a href="https://play.google.com/store/account/subscriptions">Google Play</a>
        {" "}o nelle <a href="https://apps.apple.com/account/subscriptions">impostazioni abbonamenti Apple</a>.
        Puoi richiedere la cancellazione dei dati anche con un abbonamento attivo.
      </p>
    </section>
  );
}
