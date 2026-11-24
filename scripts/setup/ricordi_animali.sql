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

-- ---------------------------------------------------------------------------
-- Data della perdita: mai nel futuro (collaudo, scheda RICORDI F41)
-- ---------------------------------------------------------------------------
-- Il selettore di data dell'app non va oltre oggi, ma l'app scrive il profilo
-- direttamente nel database e una scrittura che la aggira salvava «15 mar 2031»
-- come giorno in cui l'animale non c'e' piu'. La data e' un testo nel formato
-- dell'app («15 mar 2031», «mar 2031» o «2031», mesi in italiano): qui si legge
-- allo stesso modo e si rifiuta se e' oltre domani (UTC: un giorno di tolleranza
-- per i telefoni con il fuso orario avanti). Un testo che non si riesce a leggere
-- non viene giudicato (come fa l'app, che in quel caso non mostra nessuna data), e
-- un testo non cambiato non viene riesaminato: le righe che ci sono gia' restano
-- come sono. Vale per ogni scrittura (app, backend, SQL Editor).
-- Il nome ricordi_05_... passa prima di ricordi_10_... (e dopo plan_access_10_gate).
create or replace function public.ricordi_loss_date_not_in_future()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    parts text[];
    part_count integer;
    month_number integer := 1;
    loss date;
begin
    if new.memorial_date_label is null or btrim(new.memorial_date_label) = '' then
        return new;
    end if;
    -- IF annidati: OLD si legge solo in una modifica, mai in un inserimento.
    if tg_op = 'UPDATE' then
        if new.memorial_date_label is not distinct from old.memorial_date_label then
            return new;
        end if;
    elsif exists (
        select 1 from public.pet_profiles p
         where p.id = new.id
           and p.memorial_date_label is not distinct from new.memorial_date_label
    ) then
        -- L'app salva con un upsert: il trigger «before insert» scatta anche per una riga che
        -- esiste gia' (poi diventa una modifica). Data non cambiata = non si giudica.
        return new;
    end if;
    parts := regexp_split_to_array(btrim(new.memorial_date_label), '\s+');
    part_count := array_length(parts, 1);
    if part_count > 3 or parts[part_count] !~ '^[0-9]{4}$' then
        return new;
    end if;
    if part_count >= 2 then
        month_number := array_position(
            array['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'],
            lower(parts[part_count - 1])
        );
        if month_number is null then
            return new;
        end if;
    end if;
    begin
        loss := make_date(
            parts[part_count]::integer,
            month_number,
            case when part_count = 3 then parts[1]::integer else 1 end
        );
    exception when others then
        return new;
    end;
    -- Un'etichetta con il solo mese o il solo anno vale dal primo giorno: non si
    -- rifiuta mai a torto un mese o un anno in corso.
    if loss > (now() at time zone 'utc')::date + 1 then
        raise exception 'memorial_date_in_future'
            using errcode = 'check_violation',
                  hint = 'The date of the loss cannot be after tomorrow (UTC).';
    end if;
    return new;
end;
$$;

revoke all on function public.ricordi_loss_date_not_in_future() from public, anon, authenticated;

drop trigger if exists ricordi_05_loss_date_not_future on public.pet_profiles;
create trigger ricordi_05_loss_date_not_future
before insert or update on public.pet_profiles
for each row execute function public.ricordi_loss_date_not_in_future();

-- Per annullare la sola lettura (le colonne restano):
--   drop trigger if exists ricordi_10_profile_read_only on public.pet_profiles;
--   drop trigger if exists ricordi_10_read_only on public.<tabella>;  (le 6 sopra)
-- Per annullare il rifiuto della data futura:
--   drop trigger if exists ricordi_05_loss_date_not_future on public.pet_profiles;
--   drop function if exists public.ricordi_loss_date_not_in_future();

-- Lo schema in cache di PostgREST deve vedere subito le colonne nuove.
notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- Verifiche (solo lettura, da lanciare dopo): 7 righe attese.
-- ---------------------------------------------------------------------------
--   select event_object_table, trigger_name
--   from information_schema.triggers
--   where trigger_name like 'ricordi_10_%'
--   group by 1, 2 order by 1;
