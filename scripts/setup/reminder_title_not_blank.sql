-- PROMEMORIA SENZA TITOLO: RIFIUTATI DAL DATABASE (collaudo, scheda PROMEM F32).
-- Idempotente. Da eseguire al rilascio (in produzione lo lancia il proprietario).
--
-- L'app controlla il titolo prima di salvare e la rotta del backend (POST /reminders) rifiuta
-- un titolo vuoto o di soli spazi, ma l'app scrive i promemoria anche direttamente nel database
-- (tabella reminders): una scrittura che aggira il modulo salvava un promemoria con il titolo
-- «   » e l'elenco mostrava una riga vuota. Il trigger lo rifiuta quando la riga viene scritta
-- o quando il titolo cambia. Le righe che ci sono gia' non vengono toccate (nemmeno quelle con
-- un titolo vuoto: si possono ancora correggere o cancellare, e un cambio di data o di
-- «fatto» non ricontrolla il titolo).
--
-- Nessuna colonna e nessun dato cambiano. Senza questo script il server funziona come prima.
--
-- Che cosa NON fa, di proposito: non rifiuta le date passate. Il modulo dell'app e la rotta del
-- backend lo fanno per un promemoria NUOVO, ma una riga con una data gia' passata e' legittima
-- in altri percorsi (un promemoria scaduto che si modifica, uno ricorrente che avanza da solo,
-- un ciclo di cura che si registra dopo l'inizio) e il database non conosce il fuso orario
-- del telefono: rifiutare li' sarebbe sbagliato. Decisione da prendere, se serve, dal proprietario.

create or replace function public.reminder_title_not_blank()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    -- IF annidati: OLD si legge solo in una modifica, mai in un inserimento.
    if tg_op = 'UPDATE' then
        if new.title is not distinct from old.title then
            return new;
        end if;
    elsif exists (
        select 1 from public.reminders r
         where r.id = new.id and r.title is not distinct from new.title
    ) then
        -- L'app salva con un upsert: il trigger «before insert» scatta anche per una riga che
        -- esiste gia' (poi diventa una modifica). Titolo non cambiato = non si giudica.
        return new;
    end if;
    if new.title is null or new.title ~ '^\s*$' then
        raise exception 'reminder_title_required'
            using errcode = 'check_violation',
                  hint = 'A reminder needs a title.';
    end if;
    return new;
end;
$$;

revoke all on function public.reminder_title_not_blank() from public, anon, authenticated;

-- "valid_30_..." sorts after plan_access_10_gate and ricordi_10_read_only: the plan and the
-- Ricordi rules answer first, this one only judges the title.
drop trigger if exists valid_30_reminder_title_not_blank on public.reminders;
create trigger valid_30_reminder_title_not_blank
before insert or update on public.reminders
for each row execute function public.reminder_title_not_blank();

-- Per annullare:
--   drop trigger if exists valid_30_reminder_title_not_blank on public.reminders;
--   drop function if exists public.reminder_title_not_blank();
