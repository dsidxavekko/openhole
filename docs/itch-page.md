# itch.io page text (ready to paste)

**Title:** OpenHole

**Tagline:** You are a hole eating a city. One button and the hunted becomes the hunter.

---

## Description

OpenHole is an open-source hole-eating city game, built for GitHub Game Off 2026.

You are a hole in the ground. Swallow people, cars, trees and whole buildings, grow
bigger and eat a procedurally generated city before the clock runs out. Buildings
break into chunks and collapse into you; bigger holes hunt smaller ones.

Then press **SHIFT**.

For 3.5 seconds your hole turns small and fast. Nobody can eat you. You eat nothing
of the city. But you swallow **any** hole you dive into, however big it is. The
giant that was chasing you a second ago is now your prey, and the bots nearby
freeze in surprise before they run.

After that you are a normal hole again and must wait 8 seconds for the next Shift.
Choose the moment well.

**Modes:** Classic (2 minutes vs bots, biggest hole wins), Solo, Battle (last hole
standing, the safe zone shrinks) and a Daily challenge. Shift works in all of them.

**Maps:** a sunny day city, a warm suburb, a moonlit night city and the new sandy
**Mexico City** with terracotta low-rise blocks and a low golden sun. Cars, people
and props take their colours from the map, and every Daily challenge picks one.

## Theme: SHIFT

We read SHIFT as a **shift of roles**. In a hole-eating game size decides everything:
the big one hunts and the small one hides. Shift turns that around on purpose.
Being small becomes the dangerous state, and you pay for it:

- you shrink to 0.45× your size and move 25 % faster;
- you cannot be eaten, and the Battle zone cannot hurt you;
- you swallow any hole once you reach its inner half (shielded holes are still safe);
- you eat nothing of the city, so you stop growing while shifted;
- your other power-ups are paused until Shift ends;
- then 8 seconds of cooldown.

It is a button, not a random pick-up. You decide when to swap sides.

And the bots know it too: on **Normal** difficulty they shift sparingly (about
once per half a minute), and on **Hard** they use it freely — they slip away from
a bigger hole at the last moment, or dive into one that got careless. In Classic
the bot you shift-eat comes back out for revenge and hunts you for a while. Land
a Shift kill yourself and the game drops into a short slow-motion close-up; every
hole-vs-hole kill shows up in a kill feed, kills in quick succession build a swap
chain worth up to +100 % points, the results screen counts your Shifts and Shift
kills, and three Shift kills unlock the purple **Phase** skin. The very first
match shows a one-time hint pointing at the button.

## What's new since launch

- **v0.5.0** — bots on Normal shift too (sparingly); shift-eaten bots in Classic
  come back out for revenge; quick Shift kills build a swap chain worth up to
  +100 % points; a one-time SHIFT hint in the first match; the Daily card counts
  your Shifts; new sounds for combos, collapses and respawns.
- **v0.4.0** — Mexico City map; buildings pick models that fit their height instead
  of being stretched; map colour palettes for cars, people, props and debris.
- **v0.3.x** — night map; detailed streets (zebra crossings, tiles, manholes);
  juicier swallowing (bursts, shrinking fall, softer dust); bots hunt breakable
  buildings and slide along walls; the city percentage now counts whole objects;
  no more chunks hanging in mid-air; smoother play on phones.
- **v0.3.0** — Shift for Hard bots, slow-motion Shift kills, kill feed, Shift stats
  on the results screen, Phase skin.

## Controls

- **Touch:** drag anywhere to move (floating joystick). **SHIFT** button in the bottom-left corner.
- **PC / browser:** WASD or arrow keys to move (mouse drag works too). **Shift** key to shift.

## Credits

- Code: MIT license. Source: <https://github.com/dsidxavekko/openhole>
- 3D models: [Kenney](https://kenney.nl) (CC0)
- Font: Rubik (SIL Open Font License 1.1)
- Sound effects are synthesised in code
- Made with Godot Engine 4.7
