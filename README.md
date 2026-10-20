# MatheMinute

A Rails and Hotwire app for one-minute maths practice. Players can start as guests, register to
keep their history across devices, and practise adding and subtracting, times tables, division, negative numbers, fractions, percentages, metric conversions, equations, functions or simultaneous equations at
progressively harder levels. Times tables and division share their table facts, grouping and levels (tables 2–5,
2–12, zeroes, decimals, then both) through `Topic::Tabled`; negative numbers practises one skill a level (going
below zero, starting below zero, adding negatives, subtracting them, then multiplying and dividing), and so does
percentages (50% and 10%, 5% and 25%, combinations like 15%, 1% to 4%, then any), with whole number answers.
Metric conversions goes cm and m, then length (mm, cm, m, km), mass (mg, g, kg), volume (ml, l, kl), then imperial lengths, roughly (an inch ≈ 2.5 cm, 5 miles ≈ 8 km).
Adding and subtracting goes single digits, two digits, three digits, round numbers, then decimals, never below zero.
Fractions practises one skill a level (simplifying, adding and subtracting with the same or different
denominators, multiplying, dividing), with answers in lowest terms, typed with a fraction line.

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

A new player picks a topic first; on a new device it's the one last played.
Home (the current topic, changed on its own page with progress in each, then the streak with the daily
challenge under it) → play the daily challenge, or choose an unlocked level to learn it or practise it for a
medal → score and practice feedback → stats or play again.
The server generates questions weighted towards facts the player finds difficult. The daily challenge keeps
the streak going, and a bronze medal unlocks the next level.
The first saved game creates a guest account; registering preserves that guest's history. Signing into
an existing account switches accounts without merging guest history.

## Medals and the daily challenge

Every topic plays by medals, with 5 right for bronze, 10 for silver and 20 for gold (`MEDALS`). Practising
a level asks only that level's questions and earns bronze, silver or gold; a level shows its best, and the
first bronze unlocks the next level. Each topic's daily challenge, once a day, mixes questions from every level
up to the player's; it has its own best, earns no medal and unlocks nothing. Whether a game is a daily
challenge is in its signed ticket, so the browser can't decide. A new topic needs `MEDALS` and gets all this.

Once the day's challenge is done, mixed practice opens up: the same mix of every level up to the player's, as
often as they like, earning stars but no medals or level ups. Practising a level otherwise asks only that level's
skill: times tables, division and adding and subtracting build up (level 2 includes level 1's tables), but the
other topics' levels are each their own (functions level 5 is just inverses).

Review mode asks again, exactly, the questions a player recently got wrong in a topic (from their last 10 games,
`User::Reviewable`), up to 10, each once and with no clock. Games are ordered by play time, so a late offline
upload can't override a more recent answer. Only the latest answer to each question counts, so getting it
right takes it off the list. Like the daily challenge it's at the player's highest level and earns
no medal; a game's mode (practice, challenge or review) is in its ticket. With no clock, its answers earn no
stars, badges or question stats; finishing one earns a 50 star bonus. Every question in its signed set must
be answered before a review can be saved.

A daily challenge needs at least one submitted answer; an unanswered game leaves it available to try again.
A day counts towards the streak when any topic's daily challenge is played. Until 20 October 2026 a game of five
answers or a finished lesson counted instead (`DAILY_CHALLENGE_STREAKS_FROM`), and those days still count, so
the change cost no one a streak.

## Lessons

Every level has a minute's tutorial: a worked example in 3–4 steps tapped through one at a time, then one to
try on the game's keypad, with a hint after a wrong answer. Each topic keeps its lessons in its own `Lessons`
module (`TimesTables::Lessons`, `Equations::Lessons`, …). The one to try is a question in the topic's own form,
so the topic writes it out as the game would and works out its answer (`worked`). Lessons are offered under
the level's name and after levelling up.

Answers are checked automatically as they reach the expected length. Enter or the keypad's Check answer
button can submit a shorter answer, in both games and lessons. Keypad buttons also support keyboard and
assistive activation.

## Awards

Players collect awards (badges, in the code; they were called achievements) for their first game, scores in each topic, streaks, unlocking levels, perfect
and fast games, playing every topic, and beating their best after a week away. Every badge and its rule
is listed in `Badge::Catalogued`; the rules are questions asked of a game (`Attempt::Badgeable`), and only
look at that game and earlier ones. Each badge is earned once, by the first game to meet it, and is
celebrated on that game's results page. `User#catch_up_badges!` replays a player's games in order, which is
how existing players got their badges, and how a newly added badge can reach players who already earned it.
Badges never name the player, so shared results can show them.

## Stars

Every right answer earns stars: 10, 20 if quick and 30 if lightning fast. Each topic sets what counts as
quick in `STAR_TIMES`, since an equation takes longer than a times table. A game can also earn bonuses for a
perfect game, a new high score or levelling up. A review's answers earn none, as it has no clock; finishing
it earns a bonus. The +10s that float up during a game are only for show:
the server works out the stars from the checked answers (`Attempt::Starrable`) and keeps them on the game,
so a player's total is the sum of their games.

## Settings

The settings page has three parts: about you (picture and name, saved with its button), the game (the topic,
stars and streak freezes) and app settings (the daily reminder, colours, and sounds and vibration, which save as
they're changed).

## Groups

Players compete in groups (`Group`): an owner with an account starts one and shares its six character code
(`Group::Joinable`), and anyone can join with it, giving a name for the leaderboard if they haven't one. The owner
sets challenges (`Group::Challenge`): a topic and a level, or every level mixed, how long it runs, and whether they play too. A
challenge's round (`Group::Round`) is one set of questions made when it's set, so everyone plays the same ones; a
group game is saved against its round (the round is in its signed ticket) and earns no medals or level ups. The
leaderboard (`Group::Challenge::Rankable`) counts each player's first go: score, then fewer wrong, then who played
first by server save order; a device's clock cannot replace a counted score. Scores must reach the server before
the round ends (the challenge's end, or local midnight for a daily round); late offline games still enter personal
history. A challenge can be every day instead: a fresh round each day, the day going by the owner's time zone,
with only today's playable, and leaderboards for today and the week (Monday to Sunday) by total or best day.
Groups are invite only, show no pictures but the player's own, and have no messages. The owner can take
players out, close a challenge, or delete the group; anyone can leave. Removing a player replaces the invite code,
revoking old links without affecting existing players. Owners can also replace it themselves, and share the current
code to invite someone back. Leaving voluntarily keeps the code. Both invitation lookups and joins share a rate
limit sized for a class on one IP address. Closed daily challenges retain their final day and week's leaderboards.
Lists load only their displayed rounds and first scores, without historical question or answer JSON.
Waiting challenges show on the home page and in the daily
reminder. Groups also send push notifications (`User::Notifiable`, through `NotifyJob`): a new challenge to its
players, and to anyone who's had 1st place taken from them, at most once a day for each group. They only go to
devices with reminders on, and never between 8pm and 7am in the player's time zone.

## Error pages

The error pages in `public/` (400, 404, 422, 500) are static, so they still show when the app can't, but they're
written from the app's own header and logo by `bin/rails errors:pages` (`ErrorPage`, `app/views/errors/page`).
Run it after changing the logo or the wording.

## Sounds and vibration

A tick for a right answer, a soft buzz for a wrong one and a fanfare for a level up, in games and lessons,
plus beeps for Ready, Set, GO! and a clock ticking through a game's last 5 seconds
(`lib/feedback.js`). They're made with the Web Audio API, so there are no sound files to load or keep for
offline, and vibrate where the browser allows it (not iPhones). They're on until the player turns them off
in settings; the page says which on `<html data-sounds>`.

## Reminders

Players can turn on a daily reminder in settings, at a half hour they pick from 7am to 9pm. If they haven't
done a daily challenge by then (in their own time zone), each device they turned it on from gets a web push
notification like "🔥 Your 12 day streak is waiting", once that day (`User::Remindable`, checked every 15
minutes by `config/recurring.yml`). Each device is a `PushSubscription`, sent to only at the browsers' own push
services; one that unsubscribes is forgotten. Notifications are signed with VAPID keys kept in the credentials
(`web_push.public_key`, `web_push.private_key`). On an iPhone or iPad, web push only works once the app is on
the Home Screen.

## Streak freezes

A freeze keeps a streak going through a missed day: the day doesn't add to the streak, but doesn't end it.
Players hold up to two, bought for 10,000 stars (from the settings page) or given free when a streak reaches 7 or 30 days. Coming back
after missed days uses them up by themselves (`StreakKeeping`, before any page shows the streak), but only if
there are enough to cover every missed day. Covered days are kept as frozen days so the streak can be worked
out again later; a game played offline that turns up for a frozen day gives its freeze back.

## Authentication and offline play

New passwords require 15–72 characters, with bcrypt's additional 72-byte limit. Existing passwords
continue to work. Sessions expire on the server after 90 days. Signing in or registering rotates the
session; registration preserves the guest's browser identity and outstanding games.

Games use signed question sets bound to the browser's current player. Uploads must contain the issued
questions in order and the original game id. Retried uploads are idempotent. Tickets expire after 30 days;
unsigned games and tickets from another player are rejected before creating guest accounts.

Mixed games keep the level in their signed ticket, so levelling up before an offline upload does not
invalidate it. Avatars are served only to their owner's active session with private, no-store responses;
the default public Active Storage upload and download routes are disabled.

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
