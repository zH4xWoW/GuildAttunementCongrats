# GuildAttunementCongrats v0.2.5

Listens for Attune guild chat messages such as:
[Attune] Playername has completed Heroic Hellfire Citadel
[Attune] Playername has completed the attunement for Hellfire Citadel
Attune: Playername is now attuned to Coilfang Reservoir

When a heroic dungeon attunement/key completion is detected, the addon sends a guild-chat congrats message chosen from race/class-themed message pools.

## Slash commands:
- /gac
- /guildattunementcongrats
- /gac on | off
- /gac status
- /gac debug - toggle debug output, including ignored Attune lines
- /gac self
- /gac who - toggle hidden /who race lookup
- /gac scan - refresh guild roster cache
- /gac cache CharacterName - show cached race/class info
- /gac test [race] [class] - preview without sending to guild
- /gac parse <Attune guild chat line> - test whether a pasted Attune line matches
- /gac reset


## Installation:
Place the GuildAttunementCongrats folder in:
"World of Warcraft/_anniversary_/Interface/AddOns/"

Then restart WoW or type /reload.

## Notes:
- Race/class message selection is always enabled.
- Class is usually available from the guild roster.
- Race is collected from visible units or optional hidden /who lookup.
- If race/class cannot be found, the addon still sends a fallback heroic attunement congrats message.

## Troubleshooting:
- Use /gac status to confirm the addon is enabled.
- Use /gac debug before testing. If an Attune guild line is seen but ignored, the addon prints why.
- Use /gac test Human Paladin to verify the addon can parse and generate a message.
- Use /gac parse followed by the exact Attune guild line if the addon still ignores a real message.

## Changes in v0.2.5:
- Fixed internal saved-variable name mismatch from v0.2.4.
- Added more flexible Attune guild-chat parsing.
- Heroic detection now checks both the extracted attunement name and the full Attune guild message.
- Added /gac parse for testing pasted Attune lines.
