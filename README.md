# Combat 2 Armor (C2A)
C2A is a Combat 2.0-based health system for objects in Second Life. This repo contains all of the necessary documentation, code, and examples to interact with the system. All areas are subject to change during development of the Combat 2.0 update.
## Project Goals
- Implementation of [Combat 2.0](https://wiki.secondlife.com/wiki/Category:LSL_Combat2) functions and events
- Highly responsive, efficient scripted health system for Second Life using LSL
- Simple and easy to set up and use
- Integration of variable damage types, with damage modifiers listed on demand
- Interim compatibility with [LBA v2 by Dread Hudson](https://github.com/Krutchen/SLMCLBA)
- Moderation and monitoring tools to integrate with CombatLog (a Combat 2.0 feature)
## Differences and Advantages of C2A vs LBA
- C2A accepts damage via simple `llDamage`, `llSetDamage`, or related damage methods.
  - LBA accepts damage via `llRegionSayTo` message, on a channel derived from a slice of the hash of the object's UUID.
- C2A can process up to 720 damage instances per second, or 32 every 2 frames.
  - LBA Slim can process up to 22.5 damage messages per second, or 1 every 2 frames.
  - LBA Slim can process up to 180 collisions per second, or 8 every 2 frames.
- C2A allows for dedicated, central monitoring and moderation via CombatLog.
  - LBA performs moderation within each individual object.
- C2A provides moderation and accountability opportunities to all parties.
  - LBA provides blacklisting only for the land owner's party, if a blackbox exists and is defined in the land parcel description.
- C2A supports damage types and resistance out of the box.
  - LBA has a fixed damage cap per hit.
- C2A damage points are based on 1 point = 100 damage and stored as `float`, allowing greater flexibility.
  - LBA damage points are based on 1 point = 1 collision.
## How to Interact with C2A
### Detection
C2A objects can be detected using `llSensor("", "", PASSIVE | SCRIPTED | DAMAGEABLE, float radius, PI)` and filtered by object description in the resulting `sensor` event.

Like LBA, C2A puts a unique string into its object description. The C2A descriptor (contained within `[ ]`) can be located anywhere in the description and not just at the beginning of the string. The C2A object description is formatted like so:
```
LBA.v.[C2A LBA v0.0.0:FILTER],points,MAX_POINTS
```
- `LBA.v.` is included at the beginning for compatibility with legacy LBA weapons.
- `C2A` marks the beginning of the C2A descriptor, and is always between `[` and a space.
- `LBA` is an optional tag describing LBA compatibility. The object description will also typically start with `LBA.v.` for legacy LBA weapons.
- `v0.0.0` describes the version number of C2A in this object and is always followed by the `:` delimiter.
- `FILTER` will always be present at the end of the descriptor, is randomized on rez, and is the object name that this C2A object listens for.
- `points` is carried over from LBA to describe how many points remain, rounded down to the nearest integer. A 0 means less than 1 point remains and is not necessarily depleted.
- `MAX_POINTS` is also carried over from LBA to describe the maximum points the object can have, rounded to the nearest integer.
C2A objects also sets their health property when they have more than zero points remaining. Object health can be retrieved in the same way as avatar health: `llGetHealth(key id)` or `llGetObjectDetails(key id, [OBJECT_HEALTH])`
### Requesting information
C2A listens and sends on channel `-2453997` to objects matching the filter provided in its descriptor. The following commands are supported:
- `c2a-type`: replies with `c2a-type:` followed by the types of the C2A script in CSV format. Available and planned types include:
  - `basic`: Standard edition of C2A. See: [C2A-basic.lsl](https://github.com/ThunderRahja/combat2armor/blob/main/C2A-basic.lsl)
  - `simple`: No damage rules; takes all damage without modifiers. See: [C2A-simple.lsl](https://github.com/ThunderRahja/combat2armor/blob/main/C2A-simple.lsl)
  - `cuboid`: Has different rules per side, with six sides in a cuboid shape, similar to LBA-directional. Planned.
  - `component`: Has multiple defined volumes and different rules per volume. Possible but not planned.
  - `persistent`: Will not derez when points are depleted; useful for permanent features in the region. Planned extension of basic.
  - `short`: Short-life object that will derez in 60 seconds or less, but isn't necessarily flagged as a temporary object. Planned extension of basic.
- `c2a-rules`: replies with a pipe `|` delimited strided list of damage rules and modifiers, each in CSV format.
  - See the Damage Rules section below for details.

[C2A-reader.lsl](https://github.com/ThunderRahja/combat2armor/blob/main/C2A-reader.lsl) can read a target object's C2A data and present it in a human-readable format. To query an object, use the command `/1 check [UUID]`. To get the UUID key of an object, select it in edit mode (Ctrl + 3) and click the "Copy Keys" button in the edit window.
### Sending damage
C2A uses the built-in combat system, LLCS, to send damage. 100 LLCS damage results in 1 point of C2A damage, and damage does not get rounded off. Damage C2A objects in the same way that you would an avatar:
- Set an existing object's damage (up to 100) and then collide it with the target: [llSetPrimitiveParams](https://wiki.secondlife.com/wiki/LlSetPrimitiveParams)`([PRIM_DAMAGE, float damage, integer type])` or [llSetDamage](https://wiki.secondlife.com/wiki/LlSetDamage)`(float damage)`
- Rez an object with damage (up to 100) and then collide it with the target: [llRezObjectWithParams](https://wiki.secondlife.com/wiki/LlRezObjectWithParams)`(string inventory, [REZ_DAMAGE, float damage, REZ_DAMAGE_TYPE, integer type])`
- Send damage directly: [llDamage](https://wiki.secondlife.com/wiki/LlDamage)`(key target, float damage, integer type)`

The raw amount of points lost by a C2A object is equal to the raw damage received divided by 100. This damage may be further modified by damage rules, described in the following section.

100 damage (enough to kill an avatar) translates to 1 point removed from the C2A object's pool, assuming no modifiers, and less damage will remove a fraction of a point. Remember that non-physical objects do not collide with other non-physical objects or avatars seated on them. Damage inflicted on C2A objects will cause the region to send a CombatLog JSON message on `COMBAT_CHANNEL` from ID `COMBAT_LOG_ID`.

*Note: Some LBA munitions that damage both avatars and LBA armor on direct hit may need to be adjusted to increase their damage and/or set a damage type. Objects that have an `on_damage` or `final_damage` event cause objects with damage to immediately derez (and send damage) on collision.*
## Damage Rules
C2A is made flexible by its support of various damage rules. Here is a sample response from a C2A object with a number of rules set:
```
c2a-rules:1|*2,F5|3,7,9,10,11,14|*0|13|*0.5,C10|L|C300|?|C100
```
This is a strided list of damage types and modifiers. This list can be converted into a table for ease of reading:

| Types | Modifiers | Effect |
| --- | --- | --- |
| 1 | *2, F5 | Multiply acid damage by 2, and then increase it to at least 5. |
| 3, 7, 9, 10, 11, 14 | *0 | Nullify cold, necrotic, poison, psychic, radiant, and emotional damage. |
| 13 | *0.5, C10 | Divide sonic damage by 2, and then lower it to at most 10. |
| L | C300 | Cap LBA damage to 300. |
| ? | C100 | Cap other damage types to 100. |

I recommend supporting at least the recommended types listed on the [llDamage article](https://wiki.secondlife.com/wiki/LlDamage). There are some special types to note:
- `0` is the default damage type. All weapons that don't set a damage type (i.e. weapons scripted before the Combat2 update) will have type 0.
- `L` is the type assigned to LBA damage.
- `?` matches any type not matching a type before it (in its zone, if applicable).
- `*` matches all types, even for types that have already been handled.
- `Z` is followed by an integer, comma-separated integers, or `?`, to designate a damage zone to which any following rules apply, until another zone is designated. (C2A-cuboid and C2A-component only.)

Damage rules are explained in detail in the [settings guide](https://github.com/ThunderRahja/combat2armor/blob/main/settings_guide.md).

## How to Contribute
I am seeking feedback from content creators! This is intended to be a community project that encompasses most use cases where scripted object health is needed. If you are a content creator (for weapons, vehicles, etc.) or combat region manager and would like to join the Combat 2 Armor discussion and development Discord server, send a message to Thunder Rahja via Second Life. Alternatively, click the Issues tab to open a bug report or feature request. You can submit code changes directly by creating a fork and subsequently a pull request.
