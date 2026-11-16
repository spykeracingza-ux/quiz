# Brainwave on Roblox

Same game as the website: pick your age group, 7 prompts a day against the clock, rarer correct answers score more, and there are daily leaderboards for each age group and for everyone.

## Open it
1. On a PC or Mac, download `Brainwave.rbxlx` and open it in **Roblox Studio**.
2. **Home → Game Settings → Security →** turn on **Enable Studio Access to API Services** (needed for saving scores while testing in Studio).
3. Press **Play** to test it.

## Publish
1. **File → Publish to Roblox**, give it a name (Brainwave), then pick a genre and a thumbnail.
2. In the Creator Dashboard, set the experience to **Public** and complete the **Experience Questionnaire** (the content-maturity questions).
3. Recommended: under **Places → Settings**, set **Max players** to 20 or more, so families can play together on one server.

## What's where
| File | Goes in | What it does |
|---|---|---|
| `BrainwaveQuestions.lua` | ReplicatedStorage (ModuleScript) | All prompts and answers |
| `BrainwaveServer.server.lua` | ServerScriptService (Script) | Picks the daily prompts, checks answers on the server, runs the timer, saves profiles, leaderboards and leaderstats |
| `BrainwaveClient.client.lua` | StarterPlayer › StarterPlayerScripts (LocalScript) | Builds the whole UI |

`Brainwave.rbxlx` already has all three in place. The .lua files are copies, for editing or for use with Rojo.

## Notes
- **When rounds change:** a new round starts at 00:00 UTC (02:00 South African time). Everyone in the same age group gets the same 7 prompts that day, and at least 3 of them are about South Africa.
- **Test reset:** the game's creator (and anyone testing in Studio) sees a "Reset my daily round (test)" button.
- **Typed answers:** players' typed answers are never shown to other players. The game only displays the answers from its own list, so there's no need for chat filtering.
- **Saved data:** profiles are saved in the `BrainwaveProfiles_v1` DataStore. The daily leaderboards are OrderedDataStores named `BW_<date>_<age group>` and `BW_<date>_all`.
