## Core Gameplay Loop

1. Fly through the compact orbital arena.
2. Identify nearby trash and avoid collisions.
3. Use the pull magnet to reposition debris and the push magnet to send it away.
4. Guide trash beyond the cleanup radius around Earth.
5. Earn points for trash successfully removed from the ring.
6. Survive until the timer ends, or continue until the rocket is destroyed.
7. Review the score and restart.

## Arena and Map

### Setting
The map is a small area in low orbit around Earth. Earth is visible in the background, with a clearly marked circular cleanup boundary surrounding the planet.

### Layout
- **Compact play area:** The arena is intentionally small and crowded with trash.
- **Cleanup ring:** A visible circular boundary defines the orbital zone that must be cleared.
- **Rocket spawn:** The rocket begins in a relatively safe starting pocket, if possible
- **Trash distribution:** Debris is scattered throughout the ring, with some objects close together and others in the rocket's likely flight path.

### Trash removal rule
A piece of trash counts as cleared only when its entire collision shape crosses outside the cleanup radius. It then disappears and awards points. Trash that is still inside or touching the boundary remains active and dangerous.

The cleanup boundary is a gameplay rule, not the rocket's movement boundary. The rocket can fly around the arena, but the player is trying to move trash beyond the ring.

## Trash Objects

| Column 1 | Column 2 |
| --- | --- |
| Light Trash | Moves easily under magnetic force |
| Heavy scrap | Moves slowly and requires sustained force |
| Fast debris | Drifts quickly and is harder to avoid |
| Large Trash | Has a larger collision shape, serves as obstacles |


## Damage and Failure

- Every collision between trash and the rocket damages the rocket.
- The rocket has a limited number of health points.
- Brief damage feedback makes hits clear, such as a flash, sound, and small knockback.
- brief damage immunity after a hit prevent multiple health points being lost in a single overlap.
- When health reaches zero, the rocket explodes and the run ends.
- If the timer reaches zero first, the run ends and the player receives the final score and cleanup result.

The intended rule is that **trash should never be safe to touch**. The game should communicate danger clearly and make collisions feel avoidable rather than random.

##  Timer and Scoring

### Recommended
- **Round length:** 30/60/90/custom seconds.
- **Main score:** Points for each piece of trash that fully exits the cleanup radius - damage penalty.
- **Survival:** The player must avoid losing all rocket health.
- **High score:** Record the best score between runs

| Event | Score |
|---|---:|
| Small trash cleared | 10 |
| Medium trash cleared | 25 |
| Large trash cleared | 50 |
| Clear all trash before time expires | Bonus 100 |
| Player damage | Reduces score|


### End conditions
- **Victory / time up:** The timer reaches zero. Show score, trash cleared, and best score.
- **Destroyed:** Rocket health reaches zero before the timer ends. End the run and show the score.
- **perfect clear:** If no trash remains inside the cleanup radius, award a clear bonus. The timer can continue so players can improve their score or simply end the round early—choose one behavior and keep it consistent.

## Difficulty and Fairness

The arena should feel cluttered from the start, but difficulty must remain readable.

- Start with enough space around the rocket to allow an initial move.
- Avoid spawning trash directly inside the rocket's collision area.
- Increase danger over time by adding debris, increasing drift speed, or introducing heavier objects—not all at once.
- Use clear silhouettes and contrasting colors for trash and rocket.
- Make the cleanup radius visible at all times.
- Use consistent collision sizes and magnet ranges.
- Avoid unavoidable chains of collisions; consider brief post-hit invulnerability.