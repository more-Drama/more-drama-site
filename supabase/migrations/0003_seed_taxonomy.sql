-- MORE DRAMA · 0003 · Οι πέντε κόσμοι και οι σειρές τους (από τον Brand · Editorial · Business Guide)
-- Πραγματικά δεδομένα ταξινομίας, όχι δοκιμαστικά.

insert into public.worlds (slug, name, nav_label, description, sort_order) values
  ('discover',   'DISCOVER',      'Ανακάλυψε',            'Μέρη, επιχειρήσεις, προϊόντα και πράγματα που αξίζει να ανακαλύψει κάποιος.', 1),
  ('people',     'PEOPLE',        'Άνθρωποι',             'Οι άνθρωποι και οι ιστορίες πίσω από τον τόπο.', 2),
  ('live-drama', 'LIVE DRAMA',    'Τι κάνουμε',           'Τι κάνουμε, πού πάμε και πώς ζούμε τη Δράμα.', 3),
  ('culture',    'LOCAL CULTURE', 'Πολιτισμός και φύση',  'Φύση, πολιτισμός, κρασί, ιστορία, χωριά και εμπειρίες.', 4),
  ('community',  'COMMUNITY',     'Η δική σου Δράμα',     'Ταύτιση, χιούμορ, opinions και συμμετοχή.', 5)
on conflict (slug) do nothing;

insert into public.series (world_id, slug, name, sort_order)
select w.id, s.slug, s.name, s.sort_order
from (values
  ('people',     'people-of-drama',             'People of Drama',              1),
  ('people',     'no-drama',                    'NO DRAMA',                     2),
  ('discover',   'more-finds',                  'MORE Finds / Hidden Drama',    1),
  ('discover',   'whats-new-in-drama',          'What''s New in Drama',         2),
  ('live-drama', 'more-weekend-drama',          'MORE Weekend Drama',           1),
  ('live-drama', 'a-day-in-drama',              'A Day in Drama',               2),
  ('culture',    'more-lists',                  'MORE Lists',                   1),
  ('culture',    'culture-outside-nature',      'Culture / Outside / Nature',   2),
  ('community',  'only-draminos-will-get-it',   'Only Draminos Will Get It',    1)
) as s(world_slug, slug, name, sort_order)
join public.worlds w on w.slug = s.world_slug
on conflict (slug) do nothing;
