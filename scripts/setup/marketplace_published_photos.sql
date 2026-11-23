-- Mercatino (2026-11-23): nella cartella published/ di marketplace-photos e nel contenitore
-- privato scrive solo il backend (service_role). Policy restrittive. Idempotente. Stesso
-- blocco in supabase_schema.sql.

drop policy if exists marketplace_photos_published_insert on storage.objects;
create policy marketplace_photos_published_insert on storage.objects
as restrictive for insert to anon, authenticated
with check (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
);

drop policy if exists marketplace_photos_published_update on storage.objects;
create policy marketplace_photos_published_update on storage.objects
as restrictive for update to anon, authenticated
using (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
)
with check (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
);

drop policy if exists marketplace_photos_published_delete on storage.objects;
create policy marketplace_photos_published_delete on storage.objects
as restrictive for delete to anon, authenticated
using (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
);
