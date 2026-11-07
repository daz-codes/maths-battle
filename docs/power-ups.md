# Power-ups still to build

Built in batches of five. Batch 1 (Bomb, Ink blot, Boost, Triple points, Mini text), batch 2 (Superstar, Coins,
Homing shot, Shield, Mirror) and batch 3 (Curveball, Shot, Rocket, Decoy, Skip) are done; what's below is next.
Self power-ups go in solo games' dealt powers (`PowerUp::SOLO`), battle ones in drops (`PowerUp::BATTLE`,
`own: true` for those that help the claimer). Anything that changes a score must be worked out on the server too:
solo in `Attempt::Scorable` from the claims the ticket checks, and in a battle placed by time
(`LiveGame::Droppable#powers_in`). Anything that changes which questions are asked is reported by the game and
checked against its drop (`LiveGame::Droppable#shifts_for`), as Curveball and Rocket are.

## Next
- **Thief** (battle): swap streaks with the leader. Held back from batch 3: it needs the leader's exact streak at
  the moment it's claimed, which the server only knows once both games are saved. Either work it out from the
  leader's saved answers when the thief's game is saved (and the leader's game saved after the thief's would need
  the thief's streak too), or make it simpler, like taking half the leader's streak as bonus points.

## Later
- **Odds by place** for every drop: the leader mostly gets small or defensive items (Coins, Shield, Shot), the
  middle the attacks, and those behind the big ones. Partly there: a player far behind gets extra drops from the
  strong ones (`LiveGame::Droppable::CATCH_UP`), and only they can turn into the Bomb.
