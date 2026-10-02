-- VET APP Supabase security hardening
-- Applied to canonical project ywbuzgwbkrmkukkpysbz on 2026-10-02.
-- Safe to re-run: ALTER/REVOKE/GRANT statements are idempotent.

begin;

-- Backend-only billing tables: deny direct client access and enforce RLS.
alter table public.billing_founder_slots enable row level security;
alter table public.billing_webhook_events enable row level security;

revoke all on table public.billing_founder_slots from anon, authenticated;
revoke all on table public.billing_webhook_events from anon, authenticated;
grant all on table public.billing_founder_slots to service_role;
grant all on table public.billing_webhook_events to service_role;

-- SECURITY DEFINER billing helpers must not be callable by browser/mobile roles.
revoke execute on function public.billing_claim_founder_slot(text)
  from public, anon, authenticated;
revoke execute on function public.billing_claim_stripe_webhook_event(text, text, text, jsonb)
  from public, anon, authenticated;
revoke execute on function public.billing_create_trial_for_new_auth_user()
  from public, anon, authenticated;
revoke execute on function public.billing_enforce_pet_limit()
  from public, anon, authenticated;
revoke execute on function public.billing_mark_stripe_webhook_failed(text, text, text)
  from public, anon, authenticated;
revoke execute on function public.billing_mark_stripe_webhook_processed(text, text)
  from public, anon, authenticated;

grant execute on function public.billing_claim_founder_slot(text) to service_role;
grant execute on function public.billing_claim_stripe_webhook_event(text, text, text, jsonb) to service_role;
grant execute on function public.billing_create_trial_for_new_auth_user() to service_role;
grant execute on function public.billing_enforce_pet_limit() to service_role;
grant execute on function public.billing_mark_stripe_webhook_failed(text, text, text) to service_role;
grant execute on function public.billing_mark_stripe_webhook_processed(text, text) to service_role;

-- Pin search_path for functions flagged by the Supabase database linter.
alter function public.set_updated_at()
  set search_path = pg_catalog, extensions;

alter function ai.tier_rank(text)
  set search_path = pg_catalog, extensions;
alter function ai.rank_to_percentile(integer, integer)
  set search_path = pg_catalog, extensions;
alter function ai.recompute_registry_consensus_scores()
  set search_path = pg_catalog, extensions;
alter function ai.match_source_chunks(vector, uuid[], integer, text, text, text, boolean, text, text)
  set search_path = pg_catalog, extensions;
alter function ai.rank_source_documents(text, text, text, boolean, text, text, integer)
  set search_path = pg_catalog, extensions;

alter function public.billing_rome_midnight_after_days(timestamptz, integer)
  set search_path = pg_catalog, extensions;
alter function public.billing_rome_midnight_after_months(timestamptz, integer)
  set search_path = pg_catalog, extensions;
alter function public.billing_compute_access_expires_at(text, timestamptz)
  set search_path = pg_catalog, extensions;
alter function public.billing_effective_status(text, timestamptz)
  set search_path = pg_catalog, extensions;
alter function public.billing_has_app_access(text, timestamptz)
  set search_path = pg_catalog, extensions;

commit;
