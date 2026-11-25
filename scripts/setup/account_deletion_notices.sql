-- AVVISI E-MAIL DELL'ELIMINAZIONE (docs/compliance/18 §5).
-- Idempotente. Da eseguire PRIMA di accendere l'invio delle e-mail (EMAIL_SENDING_ENABLED):
-- il backend controlla che la colonna esista prima del primo invio e, se manca, non manda
-- nulla (altrimenti lo stesso avviso partirebbe a ogni giro).
--
-- last_notice = l'ultimo avviso della sequenza gia' inviato per questa richiesta
-- (confirmed, week_left, tomorrow). Si scrive solo se l'invio e' riuscito. Nessun
-- indirizzo, oggetto o testo: solo il nome dell'avviso.

alter table public.account_deletion_requests add column if not exists last_notice text;
-- Quando e' stato prenotato (poco prima dell'invio): la cancellazione aspetta 20 ore da li'.
alter table public.account_deletion_requests add column if not exists last_notice_at timestamptz;
