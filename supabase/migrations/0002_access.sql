-- MORE DRAMA · 0002 · Πρόσβαση (RLS και grants)
-- Τρεις «θεατές»:
--   anon           : ο επισκέπτης. Διαβάζει μόνο δημοσιευμένο, δημόσιο περιεχόμενο.
--   authenticated  : συνδεδεμένο μέλος της ομάδας. Ο ρόλος του (admin ή editor) είναι στο profiles.
--   service_role   : ο server. Παρακάμπτει το RLS. Μόνο από εκεί γράφονται υποβολές, leads, newsletter.
-- Δεν υπάρχουν δημόσιοι λογαριασμοί: η εγγραφή χρηστών στο Supabase Auth πρέπει να είναι κλειστή.

-- ---------------------------------------------------------------------------
-- Ποιος είμαι
-- ---------------------------------------------------------------------------
create or replace function app.staff_role()
returns app.staff_role
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select p.role from public.profiles p where p.id = auth.uid() and p.active;
$$;

create or replace function app.is_staff()
returns boolean
language sql
stable
as $$ select app.staff_role() is not null; $$;

create or replace function app.is_admin()
returns boolean
language sql
stable
as $$ select coalesce(app.staff_role() = 'admin', false); $$;

grant usage on schema app to anon, authenticated, service_role;
grant execute on function app.staff_role(), app.is_staff(), app.is_admin(), app.norm(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RLS παντού
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
  end loop;
end $$;

-- Ταξινομία και συντάκτες: δημόσια ανάγνωση.
create policy read_all on public.worlds  for select using (true);
create policy read_all on public.series  for select using (true);
create policy read_all on public.areas   for select using (true);
create policy read_all on public.topics  for select using (true);
create policy read_all on public.authors for select using (true);
create policy read_all on public.redirects for select using (true);
create policy read_all on public.partners for select using (true);   -- στήλες περιορίζονται με grants

create policy admin_write on public.worlds for all to authenticated using (app.is_admin()) with check (app.is_admin());
create policy admin_write on public.series for all to authenticated using (app.is_admin()) with check (app.is_admin());
create policy admin_write on public.partners for all to authenticated using (app.is_admin()) with check (app.is_admin());
create policy staff_write on public.areas   for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.topics  for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.authors for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.redirects for all to authenticated using (app.is_staff()) with check (app.is_staff());

-- Περιεχόμενο: ο επισκέπτης βλέπει μόνο ό,τι είναι published και η ώρα του έχει έρθει.
create policy read_published on public.stories for select
  using ((status = 'published' and published_at <= now()) or app.is_staff());
create policy read_published on public.guides for select
  using ((status = 'published' and published_at <= now()) or app.is_staff());
create policy read_published on public.events for select
  using ((status = 'published' and published_at <= now()) or app.is_staff());
create policy read_published on public.weekend_editions for select
  using ((status = 'published' and published_at <= now()) or app.is_staff());
create policy read_published on public.places for select
  using (status = 'published' or app.is_staff());

create policy staff_write on public.stories          for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.guides           for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.events           for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.weekend_editions for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.places           for all to authenticated using (app.is_staff()) with check (app.is_staff());

-- Πίνακες σύνδεσης: ορατοί όταν είναι ορατός ο γονέας (το RLS του γονέα ισχύει μέσα στο exists).
create policy read_with_parent on public.story_places for select
  using (exists (select 1 from public.stories s where s.id = story_id));
create policy read_with_parent on public.story_topics for select
  using (exists (select 1 from public.stories s where s.id = story_id));
create policy read_with_parent on public.guide_items for select
  using (exists (select 1 from public.guides g where g.id = guide_id));
create policy read_with_parent on public.weekend_picks for select
  using (exists (select 1 from public.weekend_editions w where w.id = edition_id));

create policy staff_write on public.story_places  for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.story_topics  for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.guide_items   for all to authenticated using (app.is_staff()) with check (app.is_staff());
create policy staff_write on public.weekend_picks for all to authenticated using (app.is_staff()) with check (app.is_staff());

-- Media: δημόσια μόνο με εγκεκριμένα, μη ληγμένα δικαιώματα.
create policy read_cleared on public.media_assets for select
  using ((rights_status = 'cleared' and (rights_expiry is null or rights_expiry >= current_date)) or app.is_staff());
create policy staff_write on public.media_assets for all to authenticated using (app.is_staff()) with check (app.is_staff());

-- Ομάδα: ο καθένας βλέπει το δικό του profile, η ομάδα βλέπει όλα, μόνο ο admin αλλάζει.
create policy read_self_or_staff on public.profiles for select to authenticated
  using (id = auth.uid() or app.is_staff());
create policy admin_write on public.profiles for all to authenticated using (app.is_admin()) with check (app.is_admin());

-- Πηγές events: η ομάδα βλέπει, ο admin ορίζει (και ποιες είναι έμπιστες).
create policy staff_read on public.event_sources for select to authenticated using (app.is_staff());
create policy admin_write on public.event_sources for all to authenticated using (app.is_admin()) with check (app.is_admin());
create policy staff_read on public.ingest_runs for select to authenticated using (app.is_staff());

-- Υποβολές κοινού: ιδιωτικές. Γράφονται μόνο από τον server, τις χειρίζεται η ομάδα.
create policy staff_read on public.submissions for select to authenticated using (app.is_staff());
create policy staff_moderate on public.submissions for update to authenticated using (app.is_staff()) with check (app.is_staff());
create policy admin_delete on public.submissions for delete to authenticated using (app.is_admin());

-- Leads και συναινέσεις newsletter: μόνο admin.
create policy admin_all on public.leads for all to authenticated using (app.is_admin()) with check (app.is_admin());
create policy admin_read on public.newsletter_consents for select to authenticated using (app.is_admin());

-- Ιστορικό και audit.
create policy staff_read on public.revisions for select to authenticated using (app.is_staff());
create policy admin_read on public.audit_log for select to authenticated using (app.is_admin());

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;

-- Επισκέπτης: μόνο ανάγνωση, μόνο δημόσιοι πίνακες.
grant usage on schema public to anon, authenticated, service_role;
grant select on
  public.worlds, public.series, public.areas, public.topics, public.authors,
  public.stories, public.story_places, public.story_topics,
  public.guides, public.guide_items, public.events,
  public.weekend_editions, public.weekend_picks, public.places, public.redirects
to anon;

-- Ιδιωτικές στήλες μένουν εκτός για τον επισκέπτη.
grant select (id, storage_key, mime, width, height, duration_ms, alt, caption, credit, focal_x, focal_y, rights_status, rights_expiry)
  on public.media_assets to anon;
grant select (id, public_name, website) on public.partners to anon;

-- Ομάδα: τα δικαιώματα γραμμής τα ορίζει το RLS παραπάνω.
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke insert, update, delete on public.audit_log, public.revisions, public.ingest_runs, public.newsletter_consents from authenticated;
revoke insert on public.submissions from authenticated;

grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

-- ---------------------------------------------------------------------------
-- Προγραμματισμένη δημοσίευση
-- ---------------------------------------------------------------------------
-- Τρέχει κάθε λίγα λεπτά από τον server (cron). Ασφαλές σε επανάληψη.
create or replace function app.publish_due()
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare n integer := 0; c integer;
begin
  update public.stories          set status = 'published' where status = 'scheduled' and published_at <= now(); get diagnostics c = row_count; n := n + c;
  update public.guides           set status = 'published' where status = 'scheduled' and published_at <= now(); get diagnostics c = row_count; n := n + c;
  update public.events           set status = 'published' where status = 'scheduled' and published_at <= now(); get diagnostics c = row_count; n := n + c;
  update public.weekend_editions set status = 'published' where status = 'scheduled' and published_at <= now(); get diagnostics c = row_count; n := n + c;
  return n;
end;
$$;

revoke all on function app.publish_due() from public, anon, authenticated;
grant execute on function app.publish_due() to service_role;
