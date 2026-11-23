-- PESATE CON DATA FUTURA: RIFIUTATE (collaudo, scheda PESO).
-- Idempotente. Da eseguire al rilascio (in produzione lo lancia il proprietario).
--
-- L'app scrive le pesate direttamente su Supabase (tabella pet_weight_measurements) e il
-- selettore di data dell'app non va oltre oggi, ma la regola non stava nel database: una
-- scrittura che aggira l'app salvava una pesata «di domani» o del 2099, e la chat poteva
-- leggerla come «l'ultima». Il trigger la rifiuta quando la riga viene scritta o quando la
-- data cambia. Tolleranza di UN giorno oltre oggi (UTC), per i telefoni con il fuso orario
-- avanti rispetto al server. Le righe che ci sono gia' non vengono toccate (nemmeno quelle
-- con una data futura: si possono ancora correggere o cancellare); il server, in ogni caso,
-- ignora le pesate oltre domani quando cerca l'ultima.
--
-- Nessuna colonna e nessun dato cambiano. Senza questo script il server funziona come prima
-- e ignora comunque le pesate future (difesa in lettura).

create or replace function public.weight_measurement_not_in_future()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if (tg_op = 'INSERT' or new.measured_at is distinct from old.measured_at)
       and new.measured_at > (now() at time zone 'utc')::date + 1 then
        raise exception 'measured_at_in_future'
            using errcode = 'check_violation',
                  hint = 'A weighing cannot be dated after tomorrow (UTC).';
    end if;
    return new;
end;
$$;

-- "weight_dates_30_..." sorts after plan_access_10_gate and ricordi_10_read_only: the plan and the
-- Ricordi rules answer first, this one only judges the date.
drop trigger if exists weight_dates_30_not_future on public.pet_weight_measurements;
create trigger weight_dates_30_not_future
before insert or update on public.pet_weight_measurements
for each row execute function public.weight_measurement_not_in_future();

-- Per annullare:
--   drop trigger if exists weight_dates_30_not_future on public.pet_weight_measurements;
--   drop function if exists public.weight_measurement_not_in_future();
