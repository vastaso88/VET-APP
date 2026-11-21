# Quokka: sito e download

Dominio quokkapet.net. Branch roberto. Root Vercel apps/website.

Stripe annullata e rimossa. Gli acquisti nativi Apple e Google saranno configurati separatamente: non sono implementati da questa modifica.

Il sito riusa Supabase tramite il backend FastAPI configurato in QUOKKA_API_URL. Account e trial usano /subscription/status. Registrazione e recupero password rimangono in app.

La home mostra due pulsanti disabilitati finche QUOKKA_IOS_STORE_URL e QUOKKA_ANDROID_STORE_URL non contengono i link HTTPS ufficiali. Ricostruire il sito dopo la configurazione.

Trial: BILLING_TRIAL_DAYS tra 10 e 15, default 14, solo nuovi account. Prima del lancio dei pagamenti verificare i piani demo storici.

Deploy Vercel: Root Directory apps/website, npm ci, npm run build. QUOKKA_API_URL deve contenere il backend HTTPS. Aggiungere quokkapet.net al progetto corretto e copiare i record DNS forniti da Vercel preservando quelli email, solo dopo autorizzazione. Nessun DNS o piano Vercel modificato.

Restano: integrazione acquisti nativi e notifiche server store, configurazione console/cataloghi, SDK Flutter compatibile, testi legali definitivi e pubblicazione.
