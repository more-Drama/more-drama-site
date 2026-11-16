-- Έλεγχοι πρόσβασης και κανόνων. Τρέχει μετά τα migrations, ως superuser, με ON_ERROR_STOP.
-- Όλα τα δεδομένα εδώ είναι ΔΟΚΙΜΑΣΤΙΚΑ και σβήνονται με το rollback στο τέλος.
\set ON_ERROR_STOP on
begin;

create schema t;
grant usage on schema t to anon, authenticated;

-- Περιμένει ότι η εντολή αποτυγχάνει. Αν πετύχει, ο έλεγχος σπάει.
create function t.fails(label text, stmt text) returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    raise notice 'ok   %  (%)', label, sqlstate;
    return;
  end;
  raise exception 'FAIL %: η εντολή έπρεπε να αποτύχει', label;
end $$;

create function t.eq(label text, got bigint, want bigint) returns void language plpgsql as $$
begin
  if got is distinct from want then raise exception 'FAIL %: πήρα %, περίμενα %', label, got, want; end if;
  raise notice 'ok   %', label;
end $$;

create function t.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', coalesce(uid::text, ''), true);
$$;
grant execute on all functions in schema t to anon, authenticated;

-- ---------------------------------------------------------------- fixtures (ως superuser)
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin@test.invalid'),
  ('00000000-0000-0000-0000-0000000000e1', 'editor@test.invalid'),
  ('00000000-0000-0000-0000-0000000000f1', 'former@test.invalid');

insert into public.profiles (id, display_name, role, active) values
  ('00000000-0000-0000-0000-0000000000a1', 'TEST Admin',  'admin',  true),
  ('00000000-0000-0000-0000-0000000000e1', 'TEST Editor', 'editor', true),
  ('00000000-0000-0000-0000-0000000000f1', 'TEST Former', 'editor', false);

insert into public.authors (id, slug, public_name) values
  ('10000000-0000-0000-0000-000000000001', 'test-author', 'TEST Author');

insert into public.partners (id, public_name, private_note) values
  ('20000000-0000-0000-0000-000000000001', 'TEST Partner', 'ιδιωτική σημείωση');

insert into public.media_assets (id, storage_key, mime, rights_status, rights_note) values
  ('30000000-0000-0000-0000-000000000001', 'test/cleared.jpg', 'image/jpeg', 'cleared', 'release #1'),
  ('30000000-0000-0000-0000-000000000002', 'test/pending.jpg', 'image/jpeg', 'pending', null);
insert into public.media_assets (id, storage_key, mime, rights_status, rights_expiry) values
  ('30000000-0000-0000-0000-000000000003', 'test/expired.jpg', 'image/jpeg', 'cleared', current_date - 1);

insert into public.stories (id, slug, title, summary, body_blocks, primary_world_id, author_id, status, published_at)
select '40000000-0000-0000-0000-000000000001', 'test-published', 'TEST Καφές στη Δράμα', 'σύνοψη',
       '[{"type":"paragraph","text":"δοκιμή"}]', w.id, '10000000-0000-0000-0000-000000000001', 'published', now() - interval '1 day'
from public.worlds w where w.slug = 'discover';

insert into public.stories (id, slug, title, status) values
  ('40000000-0000-0000-0000-000000000002', 'test-draft', 'TEST Draft', 'draft');

insert into public.stories (id, slug, title, summary, body_blocks, primary_world_id, author_id, status, published_at)
select '40000000-0000-0000-0000-000000000003', 'test-scheduled', 'TEST Scheduled', 'σύνοψη',
       '[{"type":"paragraph","text":"δοκιμή"}]', w.id, '10000000-0000-0000-0000-000000000001', 'scheduled', now() + interval '1 day'
from public.worlds w where w.slug = 'people';

insert into public.stories (id, slug, title, summary, body_blocks, primary_world_id, author_id, status, published_at)
select '40000000-0000-0000-0000-000000000004', 'test-future-published', 'TEST Future', 'σύνοψη',
       '[{"type":"paragraph","text":"δοκιμή"}]', w.id, '10000000-0000-0000-0000-000000000001', 'published', now() + interval '1 day'
from public.worlds w where w.slug = 'people';

insert into public.event_sources (id, name, url, kind, trusted) values
  ('50000000-0000-0000-0000-000000000001', 'TEST έμπιστη πηγή', 'https://trusted.test.invalid/events', 'ical', true),
  ('50000000-0000-0000-0000-000000000002', 'TEST άλλη πηγή',    'https://other.test.invalid/events',   'html', false);

insert into public.events (id, slug, title, start_at, venue_name, status, published_at, checked_at, price_kind) values
  ('60000000-0000-0000-0000-000000000001', 'test-event-live', 'TEST Συναυλία', now() + interval '3 days', 'TEST Χώρος', 'published', now() - interval '1 hour', now(), 'unknown'),
  ('60000000-0000-0000-0000-000000000002', 'test-event-queue', 'TEST Στην ουρά', now() + interval '4 days', 'TEST Χώρος', 'in_review', null, null, 'unknown');
insert into public.events (id, slug, title, start_at, venue_name, status, published_at, checked_at, event_status) values
  ('60000000-0000-0000-0000-000000000003', 'test-event-cancelled', 'TEST Ακυρώθηκε', now() + interval '5 days', 'TEST Χώρος', 'published', now() - interval '1 hour', now(), 'cancelled');

insert into public.submissions (type, payload, contact_email, consent_version) values
  ('event', '{"title":"TEST"}', 'reader@test.invalid', 'v1');
insert into public.leads (contact_name, business_name, email) values ('TEST', 'TEST ΕΠΕ', 'biz@test.invalid');
insert into public.newsletter_consents (email_hash, consent_version) values ('testhash', 'v1');

insert into public.weekend_editions (id, start_date, end_date, status) values
  ('70000000-0000-0000-0000-000000000001', date '2026-11-20', date '2026-11-22', 'draft');

-- ================================================================ ΕΠΙΣΚΕΠΤΗΣ
set local role anon;
select t.as_user(null);

select t.eq('anon βλέπει μόνο published ιστορίες που έχει έρθει η ώρα τους', (select count(*) from public.stories), 1);
select t.eq('anon βλέπει μόνο published events', (select count(*) from public.events), 2);
select t.eq('anon βλέπει μόνο media με ισχύοντα δικαιώματα', (select count(*) from public.media_assets), 1);
select t.eq('anon δεν βλέπει draft έκδοση Weekend', (select count(*) from public.weekend_editions), 0);
select t.eq('anon βλέπει τους 5 κόσμους', (select count(*) from public.worlds), 5);
select t.eq('anon βλέπει τις 9 σειρές', (select count(*) from public.series), 9);
select t.eq('anon βλέπει δημόσιο όνομα συνεργάτη', (select count(public_name) from public.partners), 1);

select t.fails('anon δεν διαβάζει υποβολές',            'select 1 from public.submissions');
select t.fails('anon δεν διαβάζει leads',               'select 1 from public.leads');
select t.fails('anon δεν διαβάζει συναινέσεις',         'select 1 from public.newsletter_consents');
select t.fails('anon δεν διαβάζει profiles',            'select 1 from public.profiles');
select t.fails('anon δεν διαβάζει πηγές events',        'select 1 from public.event_sources');
select t.fails('anon δεν διαβάζει ιστορικό εκδόσεων',   'select 1 from public.revisions');
select t.fails('anon δεν διαβάζει audit log',           'select 1 from public.audit_log');
select t.fails('anon δεν διαβάζει ιδιωτική σημείωση άδειας', 'select rights_note from public.media_assets');
select t.fails('anon δεν διαβάζει ιδιωτική σημείωση συνεργάτη', 'select private_note from public.partners');
select t.fails('anon δεν γράφει ιστορία',               $$insert into public.stories (slug, title) values ('hack', 'hack')$$);
select t.fails('anon δεν γράφει υποβολή απευθείας',     $$insert into public.submissions (type, payload, contact_email, consent_version) values ('event', '{}', 'a@b.cd', 'v1')$$);
select t.fails('anon δεν αλλάζει event',                $$update public.events set title = 'hack'$$);
select t.fails('anon δεν τρέχει προγραμματισμένη δημοσίευση', 'select app.publish_due()');
reset role;

-- ================================================================ EDITOR
set local role authenticated;
select t.as_user('00000000-0000-0000-0000-0000000000e1');

select t.eq('editor βλέπει όλες τις ιστορίες', (select count(*) from public.stories), 4);
select t.eq('editor βλέπει την ουρά events', (select count(*) from public.events where status = 'in_review'), 1);
select t.eq('editor βλέπει υποβολές', (select count(*) from public.submissions), 1);
select t.eq('editor δεν βλέπει leads', (select count(*) from public.leads), 0);
select t.eq('editor δεν βλέπει συναινέσεις newsletter', (select count(*) from public.newsletter_consents), 0);
select t.eq('editor βλέπει πηγές events', (select count(*) from public.event_sources), 2);

insert into public.stories (slug, title) values ('test-by-editor', 'TEST από editor');
select t.eq('editor δημιουργεί draft', (select count(*) from public.stories where slug = 'test-by-editor'), 1);

update public.submissions set status = 'accepted';
select t.eq('editor κάνει moderation', (select count(*) from public.submissions where status = 'accepted'), 1);

with u as (update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000000e1' returning 1)
select t.eq('editor δεν γίνεται admin μόνος του', (select count(*) from u), 0);

with u as (update public.event_sources set trusted = true where trusted = false returning 1)
select t.eq('editor δεν ορίζει έμπιστες πηγές', (select count(*) from u), 0);

select t.fails('editor δεν προσθέτει πηγή events', $$insert into public.event_sources (name, url, kind) values ('x', 'https://x.test.invalid', 'rss')$$);
select t.fails('editor δεν γράφει στο audit log',  $$insert into public.audit_log (action, entity_type) values ('x', 'x')$$);
select t.fails('editor δεν σβήνει ιστορικό',       'delete from public.revisions');
reset role;

-- ================================================================ ΑΝΕΝΕΡΓΟ ΜΕΛΟΣ
set local role authenticated;
select t.as_user('00000000-0000-0000-0000-0000000000f1');
select t.eq('ανενεργό μέλος βλέπει μόνο ό,τι και ο επισκέπτης', (select count(*) from public.stories), 1);
select t.eq('ανενεργό μέλος δεν βλέπει υποβολές', (select count(*) from public.submissions), 0);
select t.fails('ανενεργό μέλος δεν γράφει', $$insert into public.stories (slug, title) values ('former', 'x')$$);
reset role;

-- ================================================================ ADMIN
set local role authenticated;
select t.as_user('00000000-0000-0000-0000-0000000000a1');
select t.eq('admin βλέπει leads', (select count(*) from public.leads), 1);
select t.eq('admin βλέπει συναινέσεις', (select count(*) from public.newsletter_consents), 1);
with u as (update public.event_sources set trusted = true where id = '50000000-0000-0000-0000-000000000002' returning 1)
select t.eq('admin ορίζει έμπιστη πηγή', (select count(*) from u), 1);
update public.event_sources set trusted = false where id = '50000000-0000-0000-0000-000000000002';
with u as (update public.profiles set active = true where id = '00000000-0000-0000-0000-0000000000f1' returning 1)
select t.eq('admin διαχειρίζεται την ομάδα', (select count(*) from u), 1);
reset role;
select t.as_user(null);

-- ================================================================ ΚΑΝΟΝΕΣ ΔΕΔΟΜΕΝΩΝ
select t.fails('ιστορία δεν δημοσιεύεται χωρίς σύνοψη, κόσμο, συντάκτη',
  $$update public.stories set status = 'published', published_at = now() where slug = 'test-draft'$$);
select t.fails('εμπορική ιστορία θέλει συνεργάτη και ένδειξη',
  $$update public.stories set commercial_type = 'paid' where slug = 'test-published'$$);
update public.stories set commercial_type = 'paid', partner_id = '20000000-0000-0000-0000-000000000001',
       disclosure_text = 'Πληρωμένη συνεργασία με TEST Partner' where slug = 'test-published';
select t.eq('εμπορική ιστορία με ένδειξη περνά', (select count(*) from public.stories where commercial_type = 'paid'), 1);

select t.fails('event με λήξη πριν την έναρξη',
  $$update public.events set end_at = start_at - interval '1 hour' where slug = 'test-event-live'$$);
select t.fails('δωρεάν event με τιμή',
  $$update public.events set price_kind = 'free', min_price_cents = 500 where slug = 'test-event-live'$$);
select t.fails('άγνωστο κόστος με τιμή',
  $$update public.events set price_kind = 'unknown', min_price_cents = 0 where slug = 'test-event-live'$$);
select t.fails('event δεν δημοσιεύεται χωρίς χώρο',
  $$insert into public.events (slug, title, start_at, status, published_at, checked_at) values ('test-no-venue', 'x', now(), 'published', now(), now())$$);
select t.fails('event δεν δημοσιεύεται χωρίς ημερομηνία',
  $$insert into public.events (slug, title, venue_name, status, published_at, checked_at) values ('test-no-date', 'x', 'y', 'published', now(), now())$$);

select t.fails('αυτόματη δημοσίευση από μη έμπιστη πηγή',
  $$insert into public.events (slug, title, start_at, venue_name, status, published_at, checked_at, origin, source_id, source_url, external_key)
    values ('test-ingest-untrusted', 'x', now() + interval '1 day', 'y', 'published', now(), now(), 'ingest',
            '50000000-0000-0000-0000-000000000002', 'https://other.test.invalid/e/1', 'e1')$$);
insert into public.events (slug, title, start_at, venue_name, status, published_at, checked_at, origin, source_id, source_url, external_key)
  values ('test-ingest-trusted', 'TEST από έμπιστη', now() + interval '1 day', 'TEST Χώρος', 'published', now(), now(), 'ingest',
          '50000000-0000-0000-0000-000000000001', 'https://trusted.test.invalid/e/1', 'e1');
select t.eq('αυτόματη δημοσίευση από έμπιστη πηγή περνά', (select count(*) from public.events where slug = 'test-ingest-trusted' and status = 'published'), 1);
insert into public.events (slug, title, start_at, venue_name, status, origin, source_id, source_url, external_key)
  values ('test-ingest-queued', 'TEST στην ουρά', now() + interval '1 day', 'TEST Χώρος', 'in_review', 'ingest',
          '50000000-0000-0000-0000-000000000002', 'https://other.test.invalid/e/2', 'e2');
select t.eq('μη έμπιστη πηγή μπαίνει στην ουρά', (select count(*) from public.events where slug = 'test-ingest-queued' and status = 'in_review'), 1);
select t.fails('το ίδιο event από την ίδια πηγή δεν μπαίνει δύο φορές',
  $$insert into public.events (slug, title, origin, source_id, source_url, external_key)
    values ('test-ingest-dup', 'x', 'ingest', '50000000-0000-0000-0000-000000000001', 'https://trusted.test.invalid/e/1', 'e1')$$);
select t.fails('event από συλλογή χωρίς πηγή',
  $$insert into public.events (slug, title, origin) values ('test-ingest-nosrc', 'x', 'ingest')$$);

select t.fails('πρόταση Weekend με δύο στόχους',
  $$insert into public.weekend_picks (edition_id, position, event_id, guide_id, reason)
    values ('70000000-0000-0000-0000-000000000001', 0, '60000000-0000-0000-0000-000000000001', gen_random_uuid(), 'x')$$);
select t.fails('πρόταση Weekend χωρίς στόχο',
  $$insert into public.weekend_picks (edition_id, position, reason) values ('70000000-0000-0000-0000-000000000001', 0, 'x')$$);
select t.fails('ακυρωμένο event ως πρόταση Weekend',
  $$insert into public.weekend_picks (edition_id, position, event_id, reason)
    values ('70000000-0000-0000-0000-000000000001', 0, '60000000-0000-0000-0000-000000000003', 'x')$$);
insert into public.weekend_picks (edition_id, position, event_id, reason)
  values ('70000000-0000-0000-0000-000000000001', 0, '60000000-0000-0000-0000-000000000001', 'TEST λόγος');
select t.eq('έγκυρη πρόταση Weekend περνά', (select count(*) from public.weekend_picks), 1);
select t.fails('Weekend δεν δημοσιεύεται χωρίς έλεγχο',
  $$update public.weekend_editions set status = 'published', published_at = now()$$);
select t.fails('μη έγκυρο slug', $$insert into public.stories (slug, title) values ('Κακό Slug', 'x')$$);
select t.fails('μη έγκυρο email υποβολής',
  $$insert into public.submissions (type, payload, contact_email, consent_version) values ('event', '{}', 'not-an-email', 'v1')$$);

-- ================================================================ ΑΝΑΖΗΤΗΣΗ
select t.eq('κανονικοποίηση: τόνοι, κεφαλαία, τελικό σίγμα',
  (select count(*) where app.norm('ΚΑΦΈΣ στη Δράμα') = 'καφεσ στη δραμα'), 1);
select t.eq('αναζήτηση χωρίς τόνους βρίσκει τίτλο με τόνους',
  (select count(*) from public.stories where search_tsv @@ plainto_tsquery('simple', app.norm('καφες δραμα'))), 1);
select t.eq('αναζήτηση με κεφαλαία βρίσκει το ίδιο',
  (select count(*) from public.stories where search_tsv @@ plainto_tsquery('simple', app.norm('ΚΑΦΕΣ'))), 1);

-- ================================================================ ΙΣΤΟΡΙΚΟ, REDIRECTS, ΠΡΟΓΡΑΜΜΑΤΙΣΜΟΣ
update public.stories set slug = 'test-published-new' where slug = 'test-published';
select t.eq('αλλαγή slug δημιουργεί redirect',
  (select count(*) from public.redirects where old_path = '/stories/test-published' and new_path = '/stories/test-published-new'), 1);
update public.stories set slug = 'test-published-newer' where slug = 'test-published-new';
select t.eq('δεύτερη αλλαγή δεν αφήνει αλυσίδα redirects',
  (select count(*) from public.redirects where new_path = '/stories/test-published-newer'), 2);
select t.eq('κάθε αλλαγή κρατά έκδοση στο ιστορικό',
  (select count(*) from public.revisions where entity_id = '40000000-0000-0000-0000-000000000001'), 3);
select t.eq('ο μετρητής έκδοσης ανεβαίνει',
  (select version from public.stories where id = '40000000-0000-0000-0000-000000000001'), 4);

update public.stories set published_at = now() - interval '1 minute' where slug = 'test-scheduled';
select t.eq('η προγραμματισμένη δημοσίευση δημοσιεύει ό,τι έχει έρθει η ώρα του', app.publish_due()::bigint, 1);
select t.eq('δεύτερη εκτέλεση δεν κάνει τίποτα', app.publish_due()::bigint, 0);

\echo
\echo ΟΛΟΙ ΟΙ ΕΛΕΓΧΟΙ ΠΕΡΑΣΑΝ
rollback;
