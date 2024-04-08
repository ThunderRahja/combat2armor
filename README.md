# Combat 2 Armor (C2A)
C2A is a Combat 2.0-based health system for objects in Second Life. This repo contains all of the necessary documentation, code, and examples to interact with the system. All areas are subject to change during development of the Combat 2.0 update.
## Project Goals
- Focus on use of [Combat 2.0](https://wiki.secondlife.com/wiki/Category:LSL_Combat2) functions and events
- Highly responsive, highly efficient script health system for Second Life using LSL
- Simple and easy to set up and use
- Integration of variable damage types, with damage resistances provided on demand
- Interim compatibility with all editions of [LBA v2 by Dread Hudson](https://github.com/Krutchen/SLMCLBA)
- Moderation and monitoring tools to integrate with CombatLog (a Combat 2.0 feature)
## Differences and Advantages of C2A vs LBA
- C2A accepts damage via simple `llDamage`, `llSetDamage`, or related damage methods
 - LBA accepts damage via `llRegionSayTo` message, on a channel derived from a slice of the hash of the object's UUID
- C2A can process up to 720 damage instances per second, or 32 every 2 frames.
 - LBA Slim can process up to 22.5 damage messages per second, or 1 every 2 frames.
 - LBA Slim can process up to 180 collisions per second, or 8 every 2 frames.
- C2A allows for dedicated, central monitoring and moderation via CombatLog.
 - LBA performs moderation within each individual object.
- C2A provides moderation and accountability opportunities to all parties.
 - LBA provides blacklisting only for the land owner's party, if a blackbox exists and is defined in the land parcel description.
- C2A supports damage types and resistance out of the box.
 - LBA has a fixed damage cap per hit.
- C2A damage points are based on 1 bullet = 100 damage and stored as `float`, allowing greater flexibility.
 - LBA damage points are based on 1 bullet = 1 damage.
