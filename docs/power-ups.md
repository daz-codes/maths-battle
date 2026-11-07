# Power-ups still to build

Built in batches of five. Batch 1 (Bomb, Ink blot, Boost, Triple points, Mini text) is done; what's below is next,
in order. Self power-ups go in solo games' dealt powers (`PowerUp::SOLO`), attacks in battles' drops
(`PowerUp::BATTLE`). Anything that changes a score must be worked out on the server too: solo in
`Attempt::Scorable` from the claims the ticket checks, and in a battle placed by time like the Streak breaker
(`LiveGame::Droppable#hits_on`).

## Batch 2
- **Superstar** (solo and battle): for its 10 seconds anything you answer counts as right, and in a battle you
  can't be hit. Needs the server to count answers in its window as right (by time, from each answer's ms).
- **Curveball** (battle): everyone else's next 3 questions come from the hardest tier. Needs the temperature walk
  (`Ladder.walk`) to know when it hit.
- **Homing shot** (battle): hits only the player in first place, breaking their streak.
- **Horn** (battle): blocks the next attack that would hit you, the Bomb included. A defence for the leader.
- **Coins** (solo and battle): +100 points straight away.

## Batch 3
- **Shot** (battle): hits only the player just ahead of you.
- **Rocket** (battle, a catch-up item): your next 5 questions are easy ones but still score at your full streak.
- **Thief** (battle): swap streaks with the leader.
- **Skip** (solo and battle): skip a question without breaking your streak.
- **Mirror** (battle): everyone else's question shows flipped for 5 seconds.

## Batch 4
- **Decoy** (battle): everyone else's next spinner is a fake, and tapping it freezes them.
- **Odds by place** for every drop, not just the Bomb: the leader mostly gets small or defensive items (Coins,
  Horn, Shot), the middle the attacks, and those behind the big ones (Boost, Rocket, Homing shot, the Bomb).
