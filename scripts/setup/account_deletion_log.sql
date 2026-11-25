-- REGISTRO DELLE CANCELLAZIONI DEGLI ACCOUNT.
-- Idempotente. Da eseguire PRIMA di mettere online il backend che lo scrive:
-- senza tabella e bucket, "Elimina account" si ferma con un errore PRIMA di
-- cancellare qualsiasi cosa (si puo' riprovare).
--
-- Dato pseudonimizzato CONSERVATO DOPO LA CANCELLAZIONE (art. 17(3)(b)/(e) e
-- 5(2) GDPR): solo l'impronta dell'id, la data e il motivo. Mai e-mail, nome o
-- contenuti, ne' l'id di chi del team l'ha fatta. Serve a rifare la cancellazione
-- se il database viene ripristinato da un backup che ancora contiene l'account
-- (procedura in docs/security/03) e a dimostrare che e' stata fatta.
-- Durata: impostazioni DELETION_LOG_REAPPLY_DAYS (giorni di backup + 30) e
-- DELETION_LOG_PROOF_YEARS (5 anni, da confermare con la Normativa); un lavoro
-- periodico (POST /admin/lifecycle/prune-deletion-log) toglie il piu' vecchio.

create table if not exists public.account_deletion_log (
    id bigint generated always as identity primary key,
    -- SHA-256 hex of "vetapp-deletion-log-v1:" + id dell'account. Nessuna chiave.
    owner_hash text not null unique,
    deleted_at timestamptz not null default now(),
    reason text not null check (reason in (
        'user_now', 'user_period_end', 'closed_by_age_user',
        'closed_by_age_team', 'support_request', 'no_plan_expired',
        'notice_not_sent'
    )),
    -- Vuoto finche' la cancellazione e' in corso: una riga incompleta viene
    -- rifatta come le altre.
    completed_at timestamptz
);

create index if not exists idx_account_deletion_log_deleted_at
    on public.account_deletion_log (deleted_at);

-- Servizio soltanto: RLS accesa e NESSUNA policy. La chiave service_role del
-- backend la salta; anon e authenticated non vedono nulla.
alter table public.account_deletion_log enable row level security;
revoke all on public.account_deletion_log from anon, authenticated;

-- Copia fuori dal database: un oggetto per cancellazione in un bucket PRIVATO
-- senza policy di storage (solo service_role). Un ripristino del database non la
-- tocca.
insert into storage.buckets (id, name, public)
values ('deletion-log', 'deletion-log', false)
on conflict (id) do update set public = false;

-- Una tabella creata prima dei motivi nuovi (no_plan_expired, notice_not_sent):
-- si allarga il controllo. Idempotente.
alter table public.account_deletion_log drop constraint if exists account_deletion_log_reason_check;
alter table public.account_deletion_log add constraint account_deletion_log_reason_check
    check (reason in ('user_now', 'user_period_end', 'closed_by_age_user',
        'closed_by_age_team', 'support_request', 'no_plan_expired',
        'notice_not_sent'));
