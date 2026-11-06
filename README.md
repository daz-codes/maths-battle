# Maths Battle

One-minute times tables battles, solo or against other players.

- **The temperature** (`Ladder`): questions range from 2 × 3 to 0.7 × 3000 and 2.1 ÷ 0.7. A running temperature,
  warmed by quick right answers and cooled by slow or wrong ones, picks how hard the next one is. Players never see
  it. The server deals each game's questions in a signed ticket and replays the temperature to check every answer
  (`Attempt::GameTicket`).
- **Streak scoring** (`Attempt::Scorable`): 10, 20, 30… for answers right in a row, back to 10 after a wrong one.
- **Power-ups** (`PowerUp`): a spinner every 10 answers. Solo: Double points, Streak shield or Extra time, dealt in the
  ticket. In a battle one drops for everyone whenever anyone answers another 10; the first to tap it hits everyone
  else with Freeze, Scramble or a Streak breaker (`LiveGame::Droppable`).
- **Battles** (`LiveGame`): hosted with a code, or found by matchmaking (`MatchRequest`, `MatchmakingChannel`).
- **Leagues** (`League`): the world league and private ones for families and classes, ranking each player's best
  game of the day. They reset at midnight UK time.

## Running it

    bin/setup
    bin/dev

Tests: `bin/rails test` and `bin/rails test:system`.

## Deploying

`bin/kamal deploy`. Production needs its own credentials (`bin/rails credentials:edit`) and `maths-battle.daz.codes`
pointing at the server.
