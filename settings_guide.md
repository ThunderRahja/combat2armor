# C2A Settings Guide
This page serves as a guide for adjusting the available configuration options in C2A. This guide also contains a handful of helpful damage rules presets that can be copied and pasted to allow for quicker setup, even for users who are still learning the system.
## Configuration
This section contains all of the parts of C2A that are intended to be changed on an individual equipment basis.
| Setting | Description |
| --- | --- |
| `TEXT_LINK` | Floating text is displayed from this specified link number. |
| `IS_VEHICLE` | Designates this object as a vehicle to this script, making sitters invulnerable, blocking grab, and reporting hits to everyone sitting on any links of this object. Not available in C2A-simple. |
| `REPORT_THRESHOLD` | If this script is designated as a vehicle, this number is the minimum amount of damage, after adjustments, above which damage will be reported to all sitters on this object. Not available in C2A-simple. |
| `MAX_POINTS` | Specifies the maximum number of points that this object can have. |
| `DAMAGE_RULES` | This is a strided list containing all of the damage rules of this C2A script. Damage rules are covered in depth in the Damage Rules section below. |
| `DAMAGE_CONSUMABLES` | This is a list of the number of consumables used with the `$` consumable operator in damage rules. More information can be found in the Damage Rules section below. |
| `PointsChanged(…)` | This function is called after incoming damage is processed after receiving a hit or instant group of hits. It may be called multiple times per second. Out of the box, this function generates and updates the floating text and cleans up the object when points reaches 0. `newPoints` is a temporary copy of `points` that contains the number of points remaining after a change and cannot be below zero or above `MAX_POINTS`. |
### Rez Parameter
The rez parameter provided on rez determines the starting points of the object. If rezzed with param 0, the C2A script will not initialize and instead remain in the state it was in when taken to inventory. If the owner does not have full permissions and rezzes the object manually (or with param 0), the object will derez or detach immediately.
## Damage Rules
`DAMAGE_RULES` is a strided list containing pairs of types and modifiers. This list may be as simple or as complex as desired, may be requested and interpreted by other scripts, and is the center of what makes C2A unique as an object health system. 

### Damage Types
Damage types are specified as a list of comma-separated numbers and letters. Common damage types are specified in the wiki article for [llDamage](https://wiki.secondlife.com/wiki/LlDamage):

| # | Type | Description |
| --- | --- | --- |
| -1 | impact | Damage generated for avatars impacting terrain or objects. |
| 0 | generic | Generic or legacy damage before damage types were added. |
| 1 | acid | Damage caused by caustic substances. |
| 2 | blunt | Damage caused by blunt objects like a club. |
| 3 | cold | Damage caused by extreme low temperature. |
| 4 | electric | Damage caused by electricity. |
| 5 | fire | Damage caused by extreme high temperature. |
| 6 | force | Damage caused by a great force or blast. |
| 7 | necrotic | Damage caused by a life-draining magic or local poison. |
| 8 | piercing | Damage caused by a penetrating object. Not recommended for standard bullets. |
| 9 | poison | Damage caused by poison. Recommended for toxic gas. |
| 10 | psychic | Damage caused by direct assault on the mind. |
| 11 | radiant | Damage caused by radiation. |
| 12 | slash | Damage caused by a cutting edge like a sword or axe. |
| 13 | sonic | Damage caused by excessive noise. |
| 14 | emotional | Damage caused by the realization that your dreams will never become reality. |

Additionally, C2A provides some special types that may be used in damage rules:

|  | Type | Description |
| --- | --- | --- |
| L | LBA | Damage received from LBA-compatible weapons. |
| ? | undefined | If the type of damage received does not match a type before this one, it is considered undefined and is processed as this type. |
| * | all | All damage types, including those that have been processed before this one. |
| Z | zone | Designates that damage rules apply for damage zones specified in the following parameter. Rules that follow a zone designation apply only to that zone, until another zone is designated. Does not apply to C2A-basic and C2A-simple. |

Damage rules are processed in order from first to last. Even if a type is matched, processing continues until all rules have been checked. If no types are matched, and no `*` all or `?` undefined` rules apply, then damage is unmodified and received as is.

Damage types may be suffixed by `+` or `-` to apply to only positive or negative damage, respectively. For example, the type `5-` applies only to negative fire damage, such as from a welding tool.

### Damage Modifiers
Damage modifiers are a list of comma-separated operators that apply for the specified types. Most operators are followed by a value, either integer or float. Modifiers are processed in order from left to right. Operators are case-sensitive. Negative values are supported. Damage values are treated as absolute for most operators, meaning that `C100` will both reduce damage above 100 to 100 and increase damage below -100 to -100, for example.

|  | Operator | Description |
| --- | --- | --- |
| X | Excess | If the absolute value of damage is above this value, set it to 0. |
| D | Drop | If the absolute value of damage is below this value, set it to 0. |
| C | Cap | If the absolute value of damage is above this value, reduce it to value. |
| F | Floor | If the absolute value of damage is below this value, raise it to value. |
| * | Multiply | Multiply damage by this value. |
| + | Add | Increase absolute damage by this value. |
| - | Subtract | Reduce absolute damage by value, but not below zero. |
| & | Rectify | Change negative damage to positive damage. |
| ^ | Positive | Change negative damage to 0. |
| % | Chance | Continue processing modifiers after this one with a random value% chance, or stop if check fails. `%100` will always continue. |
| > | Greater | Continue processing modifiers after this one if damage is higher than value. |
| < | Less | Continue processing modifiers after this one if damage is lower than value. |
| $ | Consume | Continue processing modifiers after this one if a consumable of this value index is above zero, decrementing it by 1. |

## Damage Rule Sets for C2A-Basic
The following damage rule sets are provided for ease of copying and pasting for quick use of C2A-basic.
### Simulate LBA Full
This set caps damage to 300 per hit for damage and -20 per hit for repairs, and nullifies damage from standard bullets. This set is agnostic to damage types.
```
"*+", "C300", // cap all types of damage to 300 damage
"*-", "C20", // cap all types of repair to 20 damage
"L", "", // define LBA to exempt it from the next rule
"?", "D1.01" // drop damage below 1.01 (101 in LLCS) to zero
```
### Simulate LBA Light
This set caps damage 300 per hit for damage and -20 per hit for repairs, and bumps partial damage (0.01 to 0.99, or 1 to 99 LLCS) damage up to a full point.
```
"*+", "C300", // cap all types of damage to 300 damage
"*-", "C20", // cap all types of repair to 20 damage
"?+", "F1" // raise partial damage to 1 damage
```
### Simulate LBA Slim
Simply use C2A-simple for the minimal, bare bones experience of C2A, or use this rule set to more closely simulate LBA slim:
```
"?+", "F1" // raise partial damage to 1 damage
```
