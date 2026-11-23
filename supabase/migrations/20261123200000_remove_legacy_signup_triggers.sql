-- Via due automatismi vecchi che esistono solo in produzione (nessuno script del repository
-- li crea; trovati il 2026-11-23, docs/security/13_righe_orfane.md):
--   trg_auth_users_billing_trial    a ogni iscrizione copiava l'e-mail in owner_profiles e
--                                   dava a tutti, per sempre, il vecchio piano «trial»;
--   trg_pet_profiles_billing_limit  applicava il limite di animali di quel piano (1), anche a
--                                   chi ha Plus, Pro o Ultra. Il 2026-11-23 risulta DISABILITATO:
--                                   oggi non blocca nessuno. Il limite buono resta
--                                   plan_access_20_pet_limit (plan_access_rules.sql).
-- NON lanciare prima della conferma di chi li ha creati (il socio che cura il portale).
-- Nessuna tabella, nessuna riga: la pulizia dei dati è scripts/maintenance/erase_orphan_rows.sql.
-- Idempotente; dove i due automatismi non ci sono non fa nulla. Lo lancia il proprietario.
--
-- Si toglie la funzione, e il trigger con lei: auth.users non è nostra e «drop trigger» lì può
-- essere rifiutato, mentre la funzione è nostra. Prima si controlla che da quella funzione
-- dipenda SOLO il trigger atteso; altrimenti ci si ferma e non cambia nulla.
begin;
set local lock_timeout = '5s';

do $$
declare
    vecchio record;
    altri text;
begin
    for vecchio in
        select * from (values
            ('billing_create_trial_for_new_auth_user', 'trg_auth_users_billing_trial', 'auth.users'),
            ('billing_enforce_pet_limit', 'trg_pet_profiles_billing_limit', 'public.pet_profiles')
        ) as v(funzione, automatismo, tabella)
    loop
        if to_regprocedure('public.' || vecchio.funzione || '()') is null then
            continue;
        end if;
        select string_agg(t.tgname || ' su ' || t.tgrelid::regclass, ', ') into altri
          from pg_trigger t
         where t.tgfoid = to_regprocedure('public.' || vecchio.funzione || '()')
           and not (t.tgname = vecchio.automatismo
                    and t.tgrelid = to_regclass(vecchio.tabella));
        if altri is not null then
            raise exception 'FERMO: % serve anche a %', vecchio.funzione, altri;
        end if;
        if vecchio.funzione = 'billing_enforce_pet_limit' and not exists (
            select 1 from pg_trigger t
             where t.tgname = 'plan_access_20_pet_limit'
               and t.tgrelid = to_regclass('public.pet_profiles')
        ) then
            raise exception 'FERMO: manca plan_access_20_pet_limit, il limite resterebbe scoperto';
        end if;
        execute format('drop function public.%I() cascade', vecchio.funzione);
    end loop;
end;
$$;

commit;
