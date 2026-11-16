-- Ricordi: animali che non ci sono piu' (2026-11-16, docs/product/17_ricordi_animali.md).
-- Due parti: le scelte dei promemoria-ricordo (colonne) e la sola lettura
-- (trigger, in fondo).
-- Idempotente: si puo' eseguire piu' volte. Le colonne sono anche in
-- supabase_schema.sql (un setup nuovo le ha gia'), i trigger solo qui: ESEGUI
-- QUESTO FILE UNA VOLTA sul database esistente, e di nuovo se l'hai gia'
-- eseguito prima del 16/11/2026 sera (la sola lettura e' stata aggiunta dopo). L'app funziona anche prima (salva il resto e
-- non le scelte dei ricordi), ma le scelte non restano finche' non lo esegui.
--
-- Nessuna tabella nuova: tre scelte nel profilo dell'animale, tutte spente di
-- partenza. Valgono gia' le policy RLS "pet_profiles_*_own" della tabella e la
-- cancellazione dell'account (cancella la riga intera).
--   memorial_birthday_reminder: un pensiero nel giorno del compleanno
--   memorial_walks_reminder:    nel giorno di una passeggiata preferita
--   memorial_photos_reminder:   foto di questo giorno negli anni passati
-- La data della perdita usa la colonna gia' esistente memorial_date_label.

alter table public.pet_profiles
    add column if not exists memorial_birthday_reminder boolean not null default false;
alter table public.pet_profiles
    add column if not exists memorial_walks_reminder boolean not null default false;
alter table public.pet_profiles
    add column if not exists memorial_photos_reminder boolean not null default false;

-- ---------------------------------------------------------------------------
-- Sola lettura (richiesta del proprietario 16/11/2026, dopo la build 39)
-- ---------------------------------------------------------------------------
-- In parole semplici: un animale nei Ricordi si guarda, si esporta e si puo'
-- cancellare, ma non si cambia. L'app scrive queste tabelle direttamente nel
-- database, quindi la regola sta qui oltre che nell'app; le rotte del backend
-- fanno lo stesso controllo per conto loro (errore pet_in_memories).
-- Solo le scritture fatte con il token di un utente (app): il backend
-- (service_role) e lo SQL Editor passano, come in plan_access_rules.sql.
--
-- Cosa resta consentito:
--   - spostare nei Ricordi e riportare tra gli animali ("spostato per errore");
--   - nella scheda: data della perdita e i tre promemoria-ricordo;
--   - cancellare (una foto, un documento, l'animale intero, l'account):
--     i trigger guardano solo inserimenti e modifiche;
--   - togliere il percorso di una passeggiata vecchia (la pulizia automatica
--     dei dati di posizione continua anche per i Ricordi).
-- Codice che riceve l'app: pet_in_memories (HTTP 409, SQLSTATE PT409).

-- Vero se l'animale e' nei Ricordi. Solo per i trigger qui sotto.
create or replace function public.ricordi_pet_is_memorial(target_pet_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (select p.is_memorial from public.pet_profiles p where p.id = target_pet_id),
        false
    );
$$;

-- La scheda: mentre l'animale resta nei Ricordi, ogni altra colonna torna
-- com'era (senza errore: l'app salva la scheda intera anche quando cambia
-- solo un promemoria-ricordo).
create or replace function public.ricordi_profile_read_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if coalesce(auth.role(), '') not in ('authenticated', 'anon') then
        return new;
    end if;
    if not (old.is_memorial and new.is_memorial) then
        return new;
    end if;
    return jsonb_populate_record(
        old,
        jsonb_build_object(
            'memorial_date_label', new.memorial_date_label,
            'memorial_birthday_reminder', new.memorial_birthday_reminder,
            'memorial_walks_reminder', new.memorial_walks_reminder,
            'memorial_photos_reminder', new.memorial_photos_reminder
        )
    );
end;
$$;

-- Foto, passeggiate, pesi, documenti, patologie e promemoria: niente di nuovo
-- e nessuna modifica (nemmeno spostare una riga verso un altro animale).
create or replace function public.ricordi_child_read_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    memorial boolean;
begin
    if coalesce(auth.role(), '') not in ('authenticated', 'anon') then
        return new;
    end if;
    memorial := public.ricordi_pet_is_memorial(new.pet_id);
    -- IF annidati: OLD si legge solo in una modifica, mai in un inserimento.
    if tg_op = 'UPDATE' then
        if not memorial then
            memorial := public.ricordi_pet_is_memorial(old.pet_id);
        end if;
        if memorial and tg_table_name = 'dog_walks' then
            if (to_jsonb(new) - 'route') = (to_jsonb(old) - 'route')
                and jsonb_array_length(to_jsonb(new) -> 'route') = 0
            then
                return new;
            end if;
        end if;
    end if;
    if not memorial then
        return new;
    end if;
    raise exception using
        errcode = 'PT409',
        message = 'pet_in_memories',
        detail = 'pet in Ricordi: read, export and delete only';
end;
$$;

revoke all on function public.ricordi_pet_is_memorial(text) from public, anon, authenticated;
revoke all on function public.ricordi_profile_read_only() from public, anon, authenticated;
revoke all on function public.ricordi_child_read_only() from public, anon, authenticated;

drop trigger if exists ricordi_10_profile_read_only on public.pet_profiles;
create trigger ricordi_10_profile_read_only
before update on public.pet_profiles
for each row execute function public.ricordi_profile_read_only();

drop trigger if exists ricordi_10_read_only on public.clinical_events;
create trigger ricordi_10_read_only
before insert or update on public.clinical_events
for each row execute function public.ricordi_child_read_only();

drop trigger if exists ricordi_10_read_only on public.pet_conditions;
create trigger ricordi_10_read_only
before insert or update on public.pet_conditions
for each row execute function public.ricordi_child_read_only();

drop trigger if exists ricordi_10_read_only on public.reminders;
create trigger ricordi_10_read_only
before insert or update on public.reminders
for each row execute function public.ricordi_child_read_only();

drop trigger if exists ricordi_10_read_only on public.dog_walks;
create trigger ricordi_10_read_only
before insert or update on public.dog_walks
for each row execute function public.ricordi_child_read_only();

drop trigger if exists ricordi_10_read_only on public.pet_weight_measurements;
create trigger ricordi_10_read_only
before insert or update on public.pet_weight_measurements
for each row execute function public.ricordi_child_read_only();

drop trigger if exists ricordi_10_read_only on public.pet_photos;
create trigger ricordi_10_read_only
before insert or update on public.pet_photos
for each row execute function public.ricordi_child_read_only();

-- Per annullare la sola lettura (le colonne restano):
--   drop trigger if exists ricordi_10_profile_read_only on public.pet_profiles;
--   drop trigger if exists ricordi_10_read_only on public.<tabella>;  (le 6 sopra)

-- Lo schema in cache di PostgREST deve vedere subito le colonne nuove.
notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- Verifiche (solo lettura, da lanciare dopo): 7 righe attese.
-- ---------------------------------------------------------------------------
--   select event_object_table, trigger_name
--   from information_schema.triggers
--   where trigger_name like 'ricordi_10_%'
--   group by 1, 2 order by 1;
