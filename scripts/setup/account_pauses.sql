-- ACCOUNT IN PAUSA (docs/auth/02).
-- Idempotente. Da eseguire PRIMA di mettere online il backend che la usa: senza
-- la tabella, "Metti in pausa" risponde con un errore e nessun account viene
-- messo in pausa (il resto dell'app funziona).
--
-- Chi mette in pausa non chiede nessuna cancellazione: i dati restano, l'account
-- e' inattivo (la sessione che ha premuto il pulsante viene rifiutata, gli
-- annunci del Mercatino spariscono) e il primo accesso successivo termina la
-- pausa. La scrive solo il backend con la chiave service: nessuna policy di
-- scrittura, scritture tolte ad anon e authenticated. L'utente legge solo la
-- propria riga. Cancellata insieme all'account (supabase_account_eraser).

create table if not exists public.account_pauses (
    owner_id text primary key,
    paused_at timestamptz not null default now(),
    -- Ultimo e-mail di servizio della sequenza della pausa gia' inviata.
    last_notice text,
    last_notice_at timestamptz
);

alter table public.account_pauses enable row level security;

drop policy if exists account_pauses_select_own on public.account_pauses;
create policy account_pauses_select_own
on public.account_pauses
for select
using (owner_id = auth.uid()::text);

revoke insert, update, delete on public.account_pauses from anon, authenticated;

-- Fine della pausa (docs/compliance/18 §3.2): al rientro la riga non si cancella ma
-- prende resumed_at; l'app dice una volta "la pausa e' finita" e poi la toglie.
alter table public.account_pauses add column if not exists resumed_at timestamptz;
