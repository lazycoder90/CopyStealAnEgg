# Feature catalog — reference game (steal & defend egg genre), from 32-min video, 382 frames
NOTE: we build an ORIGINAL egg-themed game with these MECHANICS. All names of NPCs, pets, zones, eggs below are reference-only and must be replaced with original names/art.

## Core loop
Run down long lane of biome zones -> grab egg from nest near sleeping guardian (or steal from another player's pen) -> "RUN!!" banner, red screen vignette, red "Drop" button, egg carried overhead -> return past SAFE ZONE line -> place egg on pedestal in own pen -> egg grows on timer (3s first egg, up to 16h late) -> "Egg Ready!" + "Hatch!" prompt -> pet reveal (rarity / mutations+name / $/s) -> pet earns $/s while equipped -> spend cash on speed (treadmill/step pads, trails), pen upgrades, equip slots -> faster speed reaches deeper zones with better eggs. Exponential numbers (K,M,B,T,Qa).

## Start / tutorial
Spawn speed 10, $0. Red ground arrows guide. Banners "Steal an Egg!" then "Upgrade your Pen!". First egg 3s timer, hatches common pet $5/s. Plot "Unlock: $1K" sign. Intro cinematic of a giant boss guardian.

## Map
- Base hub: green field, "SAFE ZONE" painted, red boundary line, many fenced player plots side by side (one per player, home icon over own). Fence style changes per pen level.
- Hub stations: Trails Shop + FREE timed chest; Treadmill/step pads at plot (+N/step speed, upgradable Level X>Y cash or Robux; "Successfully upgraded your treadmill!"); SELL stand; Fuse Machine (0/3); mutation NPC ("Click on an egg to apply the mutation"); "MOST MONEY/S" leaderboard board; Watch-ad cash board ("Watch Ad To Collect $1.1T"); event NPC (UFO quest); limited-time lab with countdown; seasonal egg vendor; "NEXT UPDATE" countdown board.
- Lane: single long corridor, ~12+ zones in order of difficulty, banner with emoji on entry (e.g. 🙂 😐 😬 😮 😟 😱 😈 😇): forest, lake, jungle, desert, snow, lava/volcano, ocean, prehistoric, blossom/torii, cosmic, angels, titan temple, demons. Orange signs "<speed> recommended" (170K, 2.5B, 7B) — soft gate.
- Guardians: one giant creature per zone near nests, sleeping (Zzz). Taking an egg -> red "!" on guardian, wakes, chases player down lane (can chase through multiple zones). Catch consequence not shown (design: drop egg + knockback/ragdoll + egg returns to nest).

## Eggs
- Spawn in twig nests per zone; bigger/rarer egg near guardian. Periodic global "ALL EGG RESET!" respawn with server announcements "A <Rarity> <Name> Egg spawned in <Zone>!" (rarity & zone colour-coded) + on-screen countdown.
- Egg stats: weight kg (random roll), projected $/s, sell value (~80x $/s). Value grows with weight within type sublinearly.
- Placement: only in own pen ("Get closer to your area to place an egg!", "Cannot place egg here!", "Egg is too close to another egg!"). Egg model grows larger while growing.
- Growth timers 3s…16h; "Skip Growth!" prompt (Robux); "Growing Eggs" side panel list with Open buttons + "Grow All"; rewarded ad "2x Egg Growth +5 min Watch Now!"; active boost timer icon; night = x30 growth multiplier.
- HUD egg button with two badges (likely growing / ready).

## Pets
- Rarities (colour): Common (grey), Uncommon (green), Rare (blue), Epic (magenta), Legendary (gold), Mythic (red), Cosmic (purple), Secret (black w/ white outline), Eternal (pink), Divine (top). 
- Example income curve: $1/s, $5, $12, $197, $508, $908, $38K, $47K, $175K, $842K, $3.2M, $6.4M, $201M, $2B, $4.4B, $12B, $24B/s.
- Weight kg + gender symbol; same species varies by weight & mutations.
- Mutations stack with "+": Silver, Golden, Cosmic, Nitro (applied at night "Nitro mutation applied!"), Abducted (from UFO debris trade). "Apply Mutation" can fail ("The mutation failed...").
- Pets wander pen, overhead label rarity/name/$/s, "+$X" income popups. Big reveal screen on hatch.
- Equip panel: "9/9 Active", "+1 EQUIP [$75M]" rising ($500M, $50B, $500T, $5Qa), rows w/ Unequip, "Equip Best". Only active pets earn.
- Fuse Machine: "Bring 3 same Pets to Fuse / Better pets give more Luck!", 3 slots + output.
- Inventory: tabs Pets / Eggs / Gear, "All Items", search, capacity "Pets: 66/250", eggs cap ~15.
- Sell menu: tabs Eggs / Pets, Sort By Weight/Value, Select All, tiles kg/$/s/price, "Total Value", Sell. Pets sell ~100x $/s.
- Pet Index: World / Limited tabs, per-zone 8 pets, ??? silhouettes, progress "3/8", per-pet rewards ($ + speed, CLAIM!/CLAIMED!), "CLAIM ALL (n)!", "Unlocked: 32/112" (~14 zones x 8), "Equip Bat!" button. HUD badge = unclaimed.

## PvP / stealing
- Enter other player's pen, grab growing/ready egg -> "You stole an EGG!". Victim gets alert (red "!" over pen).
- Defenses: Bat gear -> hit carrier "BONK!" makes them drop egg; "TRAPPED" + 7s countdown freeze near safe zone; red hexagon shield rings around some pens (temporary lock). Safe zone.
- Players carry weapons/staffs.

## Economy
- Cash, Speed stat (shoe icon with "+" buy), UFO debris event currency, Trophies (race).
- Speed sources: treadmill/step pads (+2/step … +3,000/step, upgradable levels, cash or Robux), trails multiplier, Index rewards.
- Trails (speed multipliers): Legendary x3.5 $30M/R$79; Mythic x4 $750M/R$119; Cosmic x5 $20B/R$199; Secret x7 $500B/R$349; Eternal x10 $12.5T; Divine x14; Divine x20 $5Qa/1.1K R$.
- Pen upgrades: L1>2 ~$1M, L2>3 $75M, … L9>10 $100T, L10>11 $500T (adds capacity/visual). "Successfully upgraded your base!"
- Offline earnings "You earn $X/Day offline! 😈" (≈ 1 hour of online income).
- Friend Boost +10%.
- Monetization: Shop, "x2 Speed ONLY 3 R$" offer, Skip Growth, Grow All, Robux treadmill upgrade, rewarded ads (2x growth, cash board), FREE chest, Badge Awarded toasts.
- No rebirth seen.

## Events / cycles
- Day/night ~5 min cycle; HUD moon/sun "in Xm Ys"; big countdown before switch; night: x30 egg growth, Nitro mutation.
- Race: "Race in 2:54" -> "Race open! 4:52", "A race has appeared in <Zone>!", race down lane, podium 1ST/2ND/3RD, "+2025 Trophies".
- UFO event: NPC quest "Repair communications" -> pipe-rotation puzzle 5x5 ("ROTATE TILES TO CONNECT THE POWER") -> Signal Decoder tool ("Hold your Decoder to track it!") -> "A UFO has been sighted! Leaves In 4:48" -> "UFO FOUND! Find 3 suspicious eggs! 0/3" -> inside UFO "Smash the capsules for UFO debris!" timer -> trade debris to NPC for mutation.
- Companion quest: wisp follows player, "Grow Your Wisp" Stages 1–4, quests (Steal 20 <zone> eggs, Grow a <zone> animal, Steal any Eternal), CLAIM, "Your progress is saved".
- Seasonal: Halloween dimension countdown, Halloween egg, limited Index tab.

## HUD
Left: Shop (cart, ! badge), Index (badge), Slow Mode toggle (precision walking at high speed). Right: Egg button (2 badges), Paw (pets), Trophy (race), event orb. Bottom-left: speed + "+", cash, Friend Boost, event currency. Bottom-centre: hotbar (~10 slots: bat, decoder, items). Bottom-right: day/night timer, race timer. Top: zone banner, announcements, offline banner, mini leaderboard. Player list columns People / Speed / Money/s.
