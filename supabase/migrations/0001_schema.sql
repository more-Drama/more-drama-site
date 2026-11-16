-- MORE DRAMA · 0001 · Σχήμα βάσης (P0)
-- Στόχος: PostgreSQL 15+ / Supabase. Χρόνοι σε UTC (timestamptz), παρουσίαση Europe/Athens.
-- Ποσά σε ακέραια λεπτά (cents), νόμισμα EUR. NULL = άγνωστο, ποτέ 0 ή false.

create extension if not exists pgcrypto;
create extension if not exists unaccent;

create schema if not exists app;

-- ---------------------------------------------------------------------------
-- Τύποι
-- ---------------------------------------------------------------------------
create type app.staff_role       as enum ('admin', 'editor');
create type app.content_status   as enum ('draft', 'in_review', 'scheduled', 'published', 'archived', 'withdrawn');
create type app.commercial_type  as enum ('none', 'paid', 'gifted', 'barter', 'complimentary_client', 'affiliate');
create type app.rights_status    as enum ('pending', 'cleared', 'expired', 'rejected');
create type app.event_status     as enum ('scheduled', 'postponed', 'cancelled');
create type app.price_kind       as enum ('free', 'paid', 'unknown');
create type app.record_origin    as enum ('manual', 'ingest', 'submission');
create type app.source_kind      as enum ('rss', 'ical', 'jsonld', 'html', 'api');
create type app.submission_type  as enum ('event', 'story', 'place', 'correction');
create type app.submission_status as enum ('pending', 'needs_info', 'accepted', 'rejected');
create type app.lead_stage       as enum ('lead', 'qualified', 'contacted', 'conversation', 'proposal', 'won', 'lost');
create type app.consent_status   as enum ('pending', 'active', 'unsubscribed');
create type app.ingest_outcome   as enum ('running', 'ok', 'partial', 'failed');

-- ---------------------------------------------------------------------------
-- Βοηθητικές συναρτήσεις
-- ---------------------------------------------------------------------------

-- Κανονικοποίηση για αναζήτηση: πεζά, χωρίς τόνους, τελικό σίγμα -> σίγμα.
create or replace function app.norm(input text)
returns text
language sql
immutable
parallel safe
set search_path = public, extensions, pg_catalog
as $$
  select translate(lower(unaccent('unaccent'::regdictionary, coalesce(input, ''))), 'ς', 'σ');
$$;

-- updated_at + μετρητής έκδοσης (προστασία από ταυτόχρονο overwrite).
create or replace function app.touch()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.version := coalesce(old.version, 0) + 1;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ομάδα (δύο ρόλοι: admin, editor)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null,
  role          app.staff_role not null default 'editor',
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  version       integer not null default 1
);

create table public.authors (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  public_name  text not null,
  bio          text,
  avatar_id    uuid,
  profile_id   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  version      integer not null default 1
);

-- ---------------------------------------------------------------------------
-- Ταξινομία
-- ---------------------------------------------------------------------------
create table public.worlds (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name         text not null,            -- PEOPLE, DISCOVER, ...
  nav_label    text not null,            -- «Άνθρωποι», «Ανακάλυψε», ...
  description  text,
  sort_order   integer not null default 0
);

create table public.series (
  id           uuid primary key default gen_random_uuid(),
  world_id     uuid not null references public.worlds (id) on delete restrict,
  slug         text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name         text not null,
  description  text,
  sort_order   integer not null default 0
);

create table public.areas (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid references public.areas (id) on delete set null,
  slug         text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name         text not null,
  description  text
);

create table public.topics (
  id     uuid primary key default gen_random_uuid(),
  slug   text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name   text not null
);

-- ---------------------------------------------------------------------------
-- Media
-- ---------------------------------------------------------------------------
create table public.media_assets (
  id             uuid primary key default gen_random_uuid(),
  storage_key    text not null unique,
  mime           text not null,
  bytes          bigint check (bytes > 0),
  width          integer check (width > 0),
  height         integer check (height > 0),
  duration_ms    integer check (duration_ms > 0),
  alt            text,
  caption        text,
  credit         text,
  rights_status  app.rights_status not null default 'pending',
  rights_expiry  date,
  rights_note    text,                    -- ιδιωτική αναφορά άδειας / release
  focal_x        numeric(4,3) check (focal_x between 0 and 1),
  focal_y        numeric(4,3) check (focal_y between 0 and 1),
  capture_date   date,
  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        integer not null default 1
);

alter table public.authors
  add constraint authors_avatar_fk foreign key (avatar_id) references public.media_assets (id) on delete set null;

-- ---------------------------------------------------------------------------
-- Συνεργάτες (μόνο ό,τι χρειάζεται για τη σήμανση συνεργασίας)
-- ---------------------------------------------------------------------------
create table public.partners (
  id            uuid primary key default gen_random_uuid(),
  public_name   text not null,
  website       text check (website is null or website ~* '^https?://'),
  private_note  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  version       integer not null default 1
);

-- ---------------------------------------------------------------------------
-- Μέρη
-- ---------------------------------------------------------------------------
create table public.places (
  id               uuid primary key default gen_random_uuid(),
  slug             text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name             text not null,
  kind             text,                               -- φαγητό και ποτό, πολιτισμός, φύση ...
  area_id          uuid references public.areas (id) on delete set null,
  summary          text,
  address          text,
  lat              double precision check (lat between -90 and 90),
  lng              double precision check (lng between -180 and 180),
  website          text check (website is null or website ~* '^https?://'),
  public_phone     text,
  price_notes      text,
  hours_json       jsonb,
  kids_friendly    boolean,                            -- NULL = δεν έχει επιβεβαιωθεί
  accessible       boolean,                            -- NULL = δεν έχει επιβεβαιωθεί
  hero_asset_id    uuid references public.media_assets (id) on delete set null,
  checked_at       timestamptz,
  status           app.content_status not null default 'draft',
  created_by       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  version          integer not null default 1
);

-- ---------------------------------------------------------------------------
-- Ιστορίες (άρθρα και video stories)
-- ---------------------------------------------------------------------------
create table public.stories (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title              text not null,
  summary            text,
  body_blocks        jsonb not null default '[]'::jsonb check (jsonb_typeof(body_blocks) = 'array'),
  primary_world_id   uuid references public.worlds (id) on delete restrict,
  series_id          uuid references public.series (id) on delete set null,
  author_id          uuid references public.authors (id) on delete restrict,
  hero_asset_id      uuid references public.media_assets (id) on delete set null,
  -- SEO
  seo_title          text,
  seo_description    text,
  focus_keyword      text,
  -- Εμπορική σχέση
  commercial_type    app.commercial_type not null default 'none',
  partner_id         uuid references public.partners (id) on delete restrict,
  disclosure_text    text,
  -- Κύκλος ζωής
  status             app.content_status not null default 'draft',
  featured           boolean not null default false,
  published_at       timestamptz,
  checked_at         timestamptz,
  next_review_at     timestamptz,
  created_by         uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  version            integer not null default 1,
  search_tsv         tsvector generated always as (
                       setweight(to_tsvector('simple', app.norm(title)), 'A') ||
                       setweight(to_tsvector('simple', app.norm(summary)), 'B')
                     ) stored,
  -- Δημοσίευση μόνο με πλήρη υποχρεωτικά πεδία.
  constraint stories_publishable check (
    status not in ('scheduled', 'published')
    or (summary is not null and primary_world_id is not null and author_id is not null
        and published_at is not null and jsonb_array_length(body_blocks) > 0)
  ),
  -- Κάθε εμπορική σχέση θέλει συνεργάτη και ορατή ένδειξη.
  constraint stories_disclosure check (
    commercial_type = 'none'
    or (partner_id is not null and disclosure_text is not null and length(btrim(disclosure_text)) > 0)
  )
);

create table public.story_places (
  story_id  uuid not null references public.stories (id) on delete cascade,
  place_id  uuid not null references public.places (id) on delete cascade,
  primary key (story_id, place_id)
);

create table public.story_topics (
  story_id  uuid not null references public.stories (id) on delete cascade,
  topic_id  uuid not null references public.topics (id) on delete cascade,
  primary key (story_id, topic_id)
);

-- ---------------------------------------------------------------------------
-- Πηγές events και εκτελέσεις συλλογής
-- ---------------------------------------------------------------------------
create table public.event_sources (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  url          text not null unique check (url ~* '^https?://'),
  kind         app.source_kind not null,
  trusted      boolean not null default false,   -- μόνο οι έμπιστες δημοσιεύουν αυτόματα
  active       boolean not null default true,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  version      integer not null default 1
);

create table public.ingest_runs (
  id            uuid primary key default gen_random_uuid(),
  source_id     uuid not null references public.event_sources (id) on delete cascade,
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  outcome       app.ingest_outcome not null default 'running',
  found         integer not null default 0 check (found >= 0),
  created       integer not null default 0 check (created >= 0),
  updated       integer not null default 0 check (updated >= 0),
  queued        integer not null default 0 check (queued >= 0),
  error         text
);

-- ---------------------------------------------------------------------------
-- Events (μία εγγραφή ανά πραγματοποίηση)
-- ---------------------------------------------------------------------------
create table public.events (
  id               uuid primary key default gen_random_uuid(),
  slug             text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title            text not null,
  summary          text,                          -- δικό μας κείμενο, όχι αντιγραφή πηγής
  kind             text,                          -- μουσική, θέατρο, παιδιά, αγορά ...
  start_at         timestamptz,
  end_at           timestamptz,
  all_day          boolean not null default false,
  timezone         text not null default 'Europe/Athens',
  place_id         uuid references public.places (id) on delete set null,
  venue_name       text,                          -- όταν ο χώρος δεν είναι ακόμη εγγραφή place
  area_id          uuid references public.areas (id) on delete set null,
  organizer_name   text,
  event_status     app.event_status not null default 'scheduled',
  old_start_at     timestamptz,                   -- προηγούμενη ώρα, σε αναβολή
  price_kind       app.price_kind not null default 'unknown',
  min_price_cents  integer check (min_price_cents >= 0),
  max_price_cents  integer check (max_price_cents >= 0),
  booking_url      text check (booking_url is null or booking_url ~* '^https?://'),
  hero_asset_id    uuid references public.media_assets (id) on delete set null,
  -- Προέλευση και τεκμηρίωση
  origin           app.record_origin not null default 'manual',
  source_id        uuid references public.event_sources (id) on delete set null,
  source_url       text check (source_url is null or source_url ~* '^https?://'),
  external_key     text,                          -- σταθερό κλειδί του event στην πηγή
  content_hash     text,                          -- για εντοπισμό αλλαγών στον επανέλεγχο
  checked_at       timestamptz,
  -- Εμπορική σχέση
  commercial_type  app.commercial_type not null default 'none',
  partner_id       uuid references public.partners (id) on delete restrict,
  disclosure_text  text,
  -- Κύκλος ζωής
  status           app.content_status not null default 'draft',
  published_at     timestamptz,
  created_by       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  version          integer not null default 1,
  search_tsv       tsvector generated always as (
                     setweight(to_tsvector('simple', app.norm(title)), 'A') ||
                     setweight(to_tsvector('simple', app.norm(coalesce(summary, '') || ' ' || coalesce(venue_name, ''))), 'B')
                   ) stored,
  constraint events_dates check (end_at is null or (start_at is not null and end_at > start_at)),
  constraint events_price check (
    (price_kind = 'unknown' and min_price_cents is null and max_price_cents is null)
    or (price_kind = 'free' and coalesce(min_price_cents, 0) = 0 and coalesce(max_price_cents, 0) = 0)
    or (price_kind = 'paid' and (max_price_cents is null or min_price_cents is null or max_price_cents >= min_price_cents))
  ),
  -- Δημοσιευμένο event έχει πάντα ώρα, χώρο και ημερομηνία ελέγχου.
  constraint events_publishable check (
    status not in ('scheduled', 'published')
    or (start_at is not null and (place_id is not null or venue_name is not null)
        and published_at is not null and checked_at is not null)
  ),
  constraint events_ingest_has_source check (origin <> 'ingest' or (source_id is not null and source_url is not null)),
  constraint events_disclosure check (
    commercial_type = 'none'
    or (partner_id is not null and disclosure_text is not null and length(btrim(disclosure_text)) > 0)
  ),
  constraint events_source_key unique (source_id, external_key)
);

-- Αυτόματη δημοσίευση μόνο από έμπιστη πηγή (EVT-002).
-- Αν ένα event από συλλογή πάει σε published χωρίς άνθρωπο (created_by NULL),
-- η πηγή του πρέπει να είναι ενεργή και έμπιστη.
create or replace function app.events_guard_autopublish()
returns trigger
language plpgsql
as $$
declare
  ok boolean;
begin
  if new.origin = 'ingest'
     and new.status = 'published'
     and new.created_by is null
     and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    select s.trusted and s.active into ok from public.event_sources s where s.id = new.source_id;
    if not coalesce(ok, false) then
      raise exception 'Αυτόματη δημοσίευση επιτρέπεται μόνο από ενεργή, έμπιστη πηγή'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

create trigger events_guard_autopublish
  before insert or update on public.events
  for each row execute function app.events_guard_autopublish();

-- ---------------------------------------------------------------------------
-- Οδηγοί
-- ---------------------------------------------------------------------------
create table public.guides (
  id                uuid primary key default gen_random_uuid(),
  slug              text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title             text not null,
  summary           text,
  intro_blocks      jsonb not null default '[]'::jsonb check (jsonb_typeof(intro_blocks) = 'array'),
  selection_notes   text,                         -- κριτήρια επιλογής
  occasion          text,                         -- «βροχερή μέρα», «με παιδιά», «δωρεάν» ...
  season            text,
  primary_world_id  uuid references public.worlds (id) on delete restrict,
  author_id         uuid references public.authors (id) on delete restrict,
  hero_asset_id     uuid references public.media_assets (id) on delete set null,
  seo_title         text,
  seo_description   text,
  focus_keyword     text,
  commercial_type   app.commercial_type not null default 'none',
  partner_id        uuid references public.partners (id) on delete restrict,
  disclosure_text   text,
  status            app.content_status not null default 'draft',
  published_at      timestamptz,
  checked_at        timestamptz,
  next_review_at    timestamptz,
  created_by        uuid references public.profiles (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  version           integer not null default 1,
  search_tsv        tsvector generated always as (
                      setweight(to_tsvector('simple', app.norm(title)), 'A') ||
                      setweight(to_tsvector('simple', app.norm(summary)), 'B')
                    ) stored,
  constraint guides_publishable check (
    status not in ('scheduled', 'published')
    or (summary is not null and author_id is not null and published_at is not null and checked_at is not null)
  ),
  constraint guides_disclosure check (
    commercial_type = 'none'
    or (partner_id is not null and disclosure_text is not null and length(btrim(disclosure_text)) > 0)
  )
);

create table public.guide_items (
  id              uuid primary key default gen_random_uuid(),
  guide_id        uuid not null references public.guides (id) on delete cascade,
  position        integer not null check (position >= 0),
  place_id        uuid references public.places (id) on delete restrict,
  event_id        uuid references public.events (id) on delete restrict,
  heading         text,
  editorial_note  text,
  evidence_url    text check (evidence_url is null or evidence_url ~* '^https?://'),
  unique (guide_id, position),
  -- Το πολύ μία συνδεδεμένη οντότητα, αλλιώς αυτόνομη σημείωση με τίτλο.
  constraint guide_items_target check (
    num_nonnulls(place_id, event_id) = 1
    or (num_nonnulls(place_id, event_id) = 0 and heading is not null and editorial_note is not null)
  )
);

-- ---------------------------------------------------------------------------
-- MORE Weekend Drama
-- ---------------------------------------------------------------------------
create table public.weekend_editions (
  id            uuid primary key default gen_random_uuid(),
  start_date    date not null unique,             -- Παρασκευή· γίνεται και το slug /weekend/yyyy-mm-dd
  end_date      date not null,
  intro         text,
  status        app.content_status not null default 'draft',
  published_at  timestamptz,
  checked_at    timestamptz,
  created_by    uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  version       integer not null default 1,
  constraint weekend_dates check (end_date >= start_date and end_date - start_date <= 3),
  constraint weekend_publishable check (
    status not in ('scheduled', 'published') or (published_at is not null and checked_at is not null)
  )
);

create table public.weekend_picks (
  id               uuid primary key default gen_random_uuid(),
  edition_id       uuid not null references public.weekend_editions (id) on delete cascade,
  position         integer not null check (position >= 0),
  event_id         uuid references public.events (id) on delete restrict,
  guide_id         uuid references public.guides (id) on delete restrict,
  place_id         uuid references public.places (id) on delete restrict,
  reason           text not null,                 -- γιατί το προτείνουμε
  disclosure_text  text,
  unique (edition_id, position),
  constraint weekend_picks_one_target check (num_nonnulls(event_id, guide_id, place_id) = 1)
);

-- Ακυρωμένο event δεν μπαίνει ως πρόταση.
create or replace function app.weekend_picks_guard()
returns trigger
language plpgsql
as $$
begin
  if new.event_id is not null
     and exists (select 1 from public.events e where e.id = new.event_id and e.event_status = 'cancelled') then
    raise exception 'Ακυρωμένο event δεν μπορεί να είναι πρόταση του Weekend'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger weekend_picks_guard
  before insert or update on public.weekend_picks
  for each row execute function app.weekend_picks_guard();

-- ---------------------------------------------------------------------------
-- Κοινό: υποβολές, newsletter, αιτήματα συνεργασίας (ιδιωτικά)
-- ---------------------------------------------------------------------------
create table public.submissions (
  id               uuid primary key default gen_random_uuid(),
  reference        text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  type             app.submission_type not null,
  payload          jsonb not null check (jsonb_typeof(payload) = 'object'),
  contact_email    text not null check (contact_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  consent_version  text not null,
  consent_media    boolean not null default false,
  fingerprint      text,
  status           app.submission_status not null default 'pending',
  moderator_id     uuid references public.profiles (id) on delete set null,
  moderator_note   text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  version          integer not null default 1
);

create table public.newsletter_consents (
  id               uuid primary key default gen_random_uuid(),
  email_hash       text not null unique,          -- sha256 του κανονικοποιημένου email
  provider_id      text unique,
  consent_version  text not null,
  status           app.consent_status not null default 'pending',
  token_hash       text,
  token_expires_at timestamptz,
  source_placement text,
  confirmed_at     timestamptz,
  unsubscribed_at  timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  version          integer not null default 1,
  constraint consent_active_confirmed check (status <> 'active' or confirmed_at is not null)
);

create table public.leads (
  id              uuid primary key default gen_random_uuid(),
  contact_name    text not null,
  business_name   text not null,
  email           text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone           text,
  category        text,
  link            text check (link is null or link ~* '^https?://'),
  message         text,
  budget_range    text,
  stage           app.lead_stage not null default 'lead',
  assigned_to     uuid references public.profiles (id) on delete set null,
  next_action_at  timestamptz,
  partner_id      uuid references public.partners (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  version         integer not null default 1
);

-- ---------------------------------------------------------------------------
-- Σύστημα
-- ---------------------------------------------------------------------------
create table public.redirects (
  old_path     text primary key check (old_path ~ '^/'),
  new_path     text not null check (new_path ~ '^/'),
  status_code  integer not null default 301 check (status_code in (301, 302, 308, 410)),
  created_at   timestamptz not null default now(),
  check (old_path <> new_path)
);

create table public.revisions (
  id           uuid primary key default gen_random_uuid(),
  entity_type  text not null,
  entity_id    uuid not null,
  version      integer not null,
  snapshot     jsonb not null,
  actor_id     uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (entity_type, entity_id, version)
);

create table public.audit_log (
  id           bigint generated always as identity primary key,
  actor_id     uuid,
  action       text not null,
  entity_type  text not null,
  entity_id    uuid,
  detail       jsonb,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Triggers: updated_at / version
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','authors','media_assets','partners','places','stories','event_sources',
    'events','guides','weekend_editions','submissions','newsletter_consents','leads'
  ] loop
    execute format('create trigger %I before update on public.%I for each row execute function app.touch()', t || '_touch', t);
  end loop;
end $$;

-- Ιστορικό εκδόσεων για το δημοσιεύσιμο περιεχόμενο.
create or replace function app.snapshot()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  insert into public.revisions (entity_type, entity_id, version, snapshot, actor_id)
  values (tg_table_name, old.id, old.version, to_jsonb(old) - 'search_tsv', auth.uid())
  on conflict do nothing;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['stories','guides','events','weekend_editions','places'] loop
    execute format('create trigger %I after update on public.%I for each row execute function app.snapshot()', t || '_snapshot', t);
  end loop;
end $$;

-- Αλλαγή slug δημιουργεί redirect.
create or replace function app.slug_redirect()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare prefix text := tg_argv[0];
begin
  if new.slug is distinct from old.slug and old.status = 'published' then
    delete from public.redirects where old_path = prefix || new.slug;
    insert into public.redirects (old_path, new_path) values (prefix || old.slug, prefix || new.slug)
    on conflict (old_path) do update set new_path = excluded.new_path;
    update public.redirects set new_path = prefix || new.slug where new_path = prefix || old.slug;
  end if;
  return new;
end;
$$;

create trigger stories_slug_redirect after update of slug on public.stories
  for each row execute function app.slug_redirect('/stories/');
create trigger guides_slug_redirect after update of slug on public.guides
  for each row execute function app.slug_redirect('/guides/');
create trigger events_slug_redirect after update of slug on public.events
  for each row execute function app.slug_redirect('/events/');

-- ---------------------------------------------------------------------------
-- Ευρετήρια
-- ---------------------------------------------------------------------------
create index stories_public_idx   on public.stories (published_at desc) where status = 'published';
create index stories_world_idx    on public.stories (primary_world_id, published_at desc) where status = 'published';
create index stories_series_idx   on public.stories (series_id, published_at desc) where status = 'published';
create index stories_search_idx   on public.stories using gin (search_tsv);
create index guides_public_idx    on public.guides (published_at desc) where status = 'published';
create index guides_search_idx    on public.guides using gin (search_tsv);
create index events_upcoming_idx  on public.events (start_at) where status = 'published';
create index events_area_idx      on public.events (area_id, start_at) where status = 'published';
create index events_queue_idx     on public.events (created_at) where status = 'in_review';
create index events_search_idx    on public.events using gin (search_tsv);
create index events_recheck_idx   on public.events (checked_at) where status = 'published' and origin = 'ingest';
create index places_area_idx      on public.places (area_id);
create index submissions_open_idx on public.submissions (created_at) where status in ('pending', 'needs_info');
create index leads_stage_idx      on public.leads (stage, next_action_at);
create index ingest_runs_src_idx  on public.ingest_runs (source_id, started_at desc);
create index revisions_entity_idx on public.revisions (entity_type, entity_id, version desc);
create index media_expiry_idx     on public.media_assets (rights_expiry) where rights_expiry is not null;
