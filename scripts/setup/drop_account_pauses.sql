-- LA PAUSA DELL'ACCOUNT NON ESISTE PIU' (decisione del proprietario, 25 novembre 2026).
-- Elimina la tabella delle pause. Idempotente: si puo' lanciare piu' volte.
--
-- QUANDO: SOLO DOPO che il backend senza la pausa e' in produzione. ATTENZIONE: il vecchio backend
-- legge questa tabella nello stesso controllo che chiude gli account sotto l'eta' minima e quelli
-- in eliminazione; se la lettura fallisce, quel controllo lascia passare (fail open) anche per
-- loro. Tolta la tabella prima del nuovo backend, per quel tempo la guardia non vedrebbe nessuno.
-- La tabella e' vuota o quasi: nessuna pausa e' mai stata cancellata dal lavoro (era spento).
-- Lo lancia il PROPRIETARIO dallo SQL Editor del progetto di produzione; nulla lo lancia da solo.
--
-- Prima di lanciarlo, se vuoi sapere quanti account erano in pausa (solo un numero):
--   select count(*) from public.account_pauses;

drop table if exists public.account_pauses;

-- Dopo: select to_regclass('public.account_pauses');  -- deve rispondere null
