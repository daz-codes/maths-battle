# Power-ups still to build

Built in batches of five. Batch 1 (Bomb, Ink blot, Boost, Triple points, Mini text) and batch 2 (Superstar,
Coins, Homing shot, Horn, Mirror) are done; what's below is next, in order. Self power-ups go in solo games' dealt
powers (`PowerUp::SOLO`), battle ones in drops (`PowerUp::BATTLE`, `own: true` for those that help the claimer).
Anything that changes a score must be worked out on the server too: solo in `Attempt::Scorable` from the claims
the ticket checks, and in a battle placed by time (`LiveGame::Droppable#powers_in`).

## Batch 3
- **Curveball** (battle): everyone else's next 3 questions come from the hardest tier. Held back from batch 2:
  it changes which questions a game asks, and the server checks every answer against the questions it expects,
  so it must know exactly which answer the curveball hit. A guess from answer times that's one out would refuse
  the game. Needs the browser to report where it hit, checked against the drop (claimed by someone else, at about
  that time), before the ticket walks the questions.
- **Shot** (battle): hits only the player just ahead of you.
- **Rocket** (battle, a catch-up item): your next 5 questions are easy ones but still score at your full streak.
- **Thief** (battle): swap streaks with the leader.
- **Skip** (solo and battle): skip a question without breaking your streak.

## Batch 4
- **Decoy** (battle): everyone else's next spinner is a fake, and tapping it freezes them.
- **Odds by place** for every drop, not just the Bomb: the leader mostly gets small or defensive items (Coins,
  Horn, Shot), the middle the attacks, and those behind the big ones (Boost, Rocket, Homing shot, the Bomb).
