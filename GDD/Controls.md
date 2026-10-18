## Controls


| Input | Action |
| --- | --- |
| A / Left Arrow | Rotate rocket left |
| D / Right Arrow | Rotate rocket right |
| W / Up Arrow | Apply forward thrust |
| S / Down Arrow | Break: slowdown but no reverse |
| Z/O | Activate pull magnet |
| X/P | Activate push magnet |


### Rocket movement
- The rocket has rotation, acceleration, velocity, and momentum.
- Releasing does not stop the rocket immediately: it should use S to break, if not, momentum will keep (space has not gravity).
- Turning changes the rocket's facing direction; thrust accelerates it along its nose.
- Movement should feel slippery and challenging, but still learnable.

## Magnet Mechanics

### Pull Magnet
Creates a magnetic field around the rocket that attracts nearby trash from all directions.

- Pulls debris toward the rocket field center.
- Helps reposition trash and gather debris into a manageable path.
- Does **not** collect trash.

### Push Magnet
Creates a repulsion pulse that pushes nearby trash away from the rocket.

- Pushes debris outward in all directions within its range.
- Primary tool for moving trash toward and beyond the cleanup boundary.
- Can create space when the rocket is surrounded.
- If the trash has pull momentum and is more near to the rocket, push will be stronger (has no physical sense, but has gameplay reward)

A short cooldown or energy cost can keep the ability tactical.


