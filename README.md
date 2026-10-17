# MatheMinute

A Rails and Hotwire app for one-minute maths practice. Players can start as guests, register to
keep their history across devices, and practise times tables, equations, functions or simultaneous equations at progressively harder levels.

## Development

Requires Ruby 3.3.6, Bundler 4, SQLite 3, and libvips for avatar processing. Node 20+ runs the
JavaScript regression tests; Chrome runs the browser tests. There is no npm build step.

```sh
bundle install
bin/setup --skip-server
bin/dev
```

Open http://localhost:3000. Import maps and Propshaft serve the JavaScript and CSS directly.
SQLite databases and uploaded avatars live in `storage/`.

## Checks

```sh
bin/rails db:test:prepare test
node --test test/javascript/*.mjs
bin/rails test:system
bin/rubocop
bin/brakeman --quiet --no-pager
bin/bundler-audit
bin/importmap audit
```

`bin/ci` runs setup and all checks. Browser tests clear persistent client state between cases and run
sequentially because concurrent browser workers can contend for SQLite writes.

## Application flow

Home → choose a topic and unlocked level → 60-second game → score and practice feedback → stats or play again.
The server generates questions weighted towards facts the player finds difficult. Five answers make a
game count towards a streak. Three games with at least 20 answers and 90% accuracy unlock the next level.
The first saved game creates a guest account; registering preserves that guest's history. Signing into
an existing account switches accounts without merging guest history.

## Achievements

Players collect achievements (badges, in the code) for their first game, scores in each topic, streaks, unlocking levels, perfect
and fast games, playing every topic, and beating their best after a week away. Every badge and its rule
is listed in `Badge::Catalogued`; the rules are questions asked of a game (`Attempt::Badgeable`), and only
look at that game and earlier ones. Each badge is earned once, by the first game to meet it, and is
celebrated on that game's results page. `User#catch_up_badges!` replays a player's games in order, which is
how existing players got their badges, and how a newly added badge can reach players who already earned it.
Badges never name the player, so shared results can show them.

## Authentication and offline play

New passwords require 15–72 characters, with bcrypt's additional 72-byte limit. Existing passwords
continue to work. Sessions expire on the server after 90 days. Signing in or registering rotates the
session; registration preserves the guest's browser identity and outstanding games.

Games use signed question sets bound to the browser's current player. Uploads must contain the issued
questions in order and the original game id. Retried uploads are idempotent. Tickets expire after 30 days;
unsigned games and tickets from another player are rejected before creating guest accounts.

The service worker caches home, game, and stats pages per player and URL, including the selected level.
Account changes clear the previous cache. Late responses cannot restore an earlier player's cache, and
expired sessions cannot open cached private pages offline. The local game queue is also separated by
player. Storage failures offer a retry without claiming the game was saved.

Each game page supplies six single-use question sets. When the offline supply runs out, reconnect to
load more. This prevents invented questions and replayed games; it cannot prove human input or honest
timing on a device controlled by the player. Competitive scores would require online supervision.

The security update discards old, unowned browser queues and cached pages because they cannot safely
be attributed to an account. Ask players with pending offline games to reconnect before deploying.

## Production

The app uses Rails 8.1.4, Puma, SQLite, Solid Queue/Cache/Cable, and Kamal. Production enforces HTTPS.
A content security policy restricts scripts to the app and nonced import maps, with explicit Google Fonts
sources. `CDN_HOST` optionally allows the configured asset host.

Configure `config/deploy.yml` for the host and registry, provide `KAMAL_REGISTRY_PASSWORD` in the
environment, and keep `config/master.key` outside Git. `bin/kamal deploy` builds the image and prepares
the database. The `matheminute_storage` volume persists databases and uploads; arrange off-server
backups for this volume. Daily jobs remove expired sessions and abandoned guest accounts.
