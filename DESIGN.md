# ASTRA / Art Direction

An original portrait, one-thumb, vertical scrolling arcade plane shooter.

- Visual reference era: late 1980s arcade cabinets and 16-bit handheld military games.
- Identity: midnight-navy #081221, bone #F4F2DB, sea-cyan #6AE6DE, signal orange #FFC078, hostile coral #F5786D.
- Typography: condensed heavy display titling, restrained Menlo mono telemetry. Never default dashboard typography.
- UI: spare bars, squared steel switches and military markings, strong left-aligned score. No purple gradients, glass blur, nested cards, emojis, default system icon menus, or decorative shadows.
- Art: original fixed-grid 2D sprites and chip-wave audio, tightly matching vehicle silhouettes.
- Mechanic: portrait touch-drag with positive vertical offset so the finger doesn't hide the ship. Automatic fire. Large, legible bomb affordance. Flash brief and subtle.
- Challenge: readable bullet patterns, telegraphed boss, 3 hull lives, recoverable powerups, fair center hitbox.
- States: illustrated attract/menu, gameplay HUD, deliberate paused overlay, final results/replay.
- Motion: constant parallax sky, enemy lateral drift, pixel debris, precession on pickups, ship hovering on attract.
- Maintain 60 Hz frame cap and clamp delta time to avoid skipping bullets after app suspension.
