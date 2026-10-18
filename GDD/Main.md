# Orbital Trash

**Genre:** Arcade / Physics-based survival
**Graphics**: 2D topdown
**Engine**: Raylib (D)

## Overview

The player pilots a small rocket through a crowded ring of orbital trash around Earth. The arena is compact and cluttered, making navigation difficult. The objective is to push every piece of trash beyond the designated orbital cleanup radius before time runs out, while avoiding collisions.

Trash is **not collected**. It remains a hazard until it has been pushed outside the cleanup boundary. If trash touches the rocket, the rocket takes damage. The run ends if the rocket loses all its health or the timer reaches zero.

## Design

- **Clear the orbit:** Move trash out of the marked cleanup ring.
- **Risk versus reward:** The pull magnet can help reposition trash, but bringing debris close to the rocket is dangerous.
- **Hard to master flight:** Rocket momentum and rotation make precise movement challenging.
- **Readable chaos:** The arena is crowded, but players should be able to understand threats and react fairly.
- **Replayable scoring:** Each run challenges players to clear more trash, survive longer, and improve their high score.

> The player does not collect trash. The player uses magnetic forces to push trash completely outside the orbital cleanup ring. Every piece of trash inside the ring remains a collision hazard, and any collision damages the rocket.

> The game's challenge is to clean a crowded orbit with precise, momentum-based flight while managing risk, time, and rocket health.

