# Development Progress

> Live project-development context for a fresh chat. Keep this current and concise. Remove or compress superseded detail once it no longer affects future work.

## Current
- Branch: `dev`
- Version: `0.1.10-dev`
- Current runtime checkpoint: `65ddb913d1ee3d88de2cfbbda7a31d665311364f` — BoP/Cena presentation now uses a self-contained pfUI-style repeated `zoomfade` icon pulse; `/wg debug cena [1|2|3]` remains mode-agnostic on dev and the real BoP path remains ringer -> client only.
- Current `dev` head before this handoff update: `15db2ffc0a09648bf3a486c7f9acbcb78956d5dd`; later commits after the runtime checkpoint are one-shot checker add/remove housekeeping only and no temporary workflow remains.
- Stable runtime baseline: `0.1.9` at `09f6dd18bd56faca23e0336a463e6969bba6849e`.
- Current `main` head: `8e4926cdb30042d2e025209262236bbce5f8fa2a` (still `0.1.9`; later commits are presentation-only).
- Goal: complete real two-client verification of the rank-aware BoP/Cena slice, then fix only demonstrated runtime issues before any release work.
- Current scope boundary: testing and targeted fixes only. Do not retune proven geometry without runtime evidence, and do not start options/minimap/framework/public multi-user security work.

## Current Design / Development Contract

### Architecture / Ownership
- Target is WoW 1.12.1 / Interface 11200 / Lua 5.0.
- Runtime remains a single main `WanderingGaia.lua` plus `locales/enUS.lua`; dev-only debug commands are integrated in the main file and must not ship in a stable build.
- ClassicAPI supplies the position/facing data used by directional placement and the spellcast/aura data used by the BoP feature. The next runtime pass assumes both clients have ClassicAPI.
- Addon communication deliberately uses the proven Vanilla path: `SendAddonMessage(prefix, payload, "RAID"/"PARTY")`, `CHAT_MSG_ADDON`, and legacy `arg1`/ `arg2`/ `arg4`; do not introduce `RegisterAddonMessagePrefix` or `C_ChatInfo`.
- Runtime starts in client mode. `/wg ringer` and `/wg client` are mutually exclusive modes.
- The ringer owns discovered-client and outgoing-ring state; each client owns incoming-ring presentation state. Outgoing state is per recipient and incoming state is per sender, so simultaneous independent rings remain valid.

### Invariants
- `CHAT_MSG_ADDON arg4` is the authoritative remote sender identity. Normal remote messages reject self/non-group senders.
- A ringer may target Ring Bell or BoP communication only at positively discovered grouped clients; a client accepts BoP only from a grouped peer currently known as a ringer.
- Existing recipient cancellation semantics are intentional: if the client is already targeting the ringer when `RING:1` arrives, the ring still appears. Cancellation occurs only on a later `PLAYER_TARGET_CHANGED` onto that ringer.
- Ring state must stay independent per recipient. Do not add a single-recipient restriction, forced replacement, or unrelated ringing guardrail.
- Sender control behavior is product behavior: left click sends/re-sends `RING:1` with a per-recipient `3.14s` throttle; right click clears local outgoing state and sends `RING:0` immediately with no stop throttle.
- Preserve the user-tested geometry unless a runtime regression requires a deliberate change:
  - `minrange=0`
  - `origin=0:-10`
  - `inner=5:15`
  - `outer=40:60:25`
  - `curve=0:0,10:20,20:60,44:80,80:100`
  - `size=64:16`
  - `smooth=50`
- Settings revision `2` intentionally resets older tuning once to those defaults; later user edits persist.
- Live `UnitPosition(ringer)` is primary. When it is lost during an active ring, the last usable same-map endpoint may be cached; the recipient position/facing remain live; stale-target placement is forced to the outer/far geometry. Cache/request state clears when the ring ends and unusable map state must not be treated as valid position data.
- Native 1.12.1 has no camera pitch/projection data for true vertical screen projection; Z affects radial distance only.

### Protocol / Data Model
- Discovery/mode:
  - `Q` — discovery query.
  - `MODE:C` — client announcement.
  - `MODE:R` — ringer announcement.
- Ring control:
  - `RING:1:<recipient>` — start/re-ring the named recipient.
  - `RING:0:<recipient>` — stop the named recipient.
  - `CANCEL:<ringer>` — recipient cancellation back to the named ringer.
- Remote position refresh:
  - `POSQ:<ringer>` — an actively rung client requests the named ringer's position only after local `UnitPosition` is unavailable; requests are capped at one per second per active ringer.
  - `POS:<recipient>:<map>:<west>:<north>:<z-or-n>` — ringer reply. Only the named active recipient consumes it, while addon-message `arg4` remains authoritative sender identity.
  - Ringer replies only when in ringer mode, the requester is grouped, the request names the local player, and that requester currently has an active outgoing ring.
  - Older clients safely ignore unknown `POSQ`/`POS` messages.
- BoP:
  - `BOP:<recipient>` — sent only after a matching successful local Blessing of Protection cast at a still-discovered grouped client.
  - Supported spell IDs are `1022`, `5599`, and `10278`.
  - `UNIT_SPELLCAST_SENT` records target + castGUID + spellID; matching interrupted/failed/failed-quiet events clear the pending cast without sending; only matching `UNIT_SPELLCAST_SUCCEEDED` sends.
  - Receiver accepts only while in client mode, for the local player, from a currently known grouped ringer, then waits up to `1.5s` for a matching BoP aura whose ClassicAPI `sourceUnit` or `sourceGUID` resolves to the same sender.

### Active Decisions
- Sender control bell position mirrors the configured visual-origin Y offset; it animates only while the currently targeted recipient has an active outgoing ring and resets to frame 1 when inactive.
- If local ringer position disappears after a usable endpoint was known, bearing continues from the recipient's live position/facing to the cached endpoint. If a ring starts with no usable endpoint yet, the existing non-directional origin fallback remains until usable local/remote position arrives.
- BoP presentation is a 64 px aura icon at `UIParent CENTER`, X `-200`, Y `0`, with `Spell_Holy_SealOfProtection` fallback. The earlier pulsing `UI-ActionButton-Border` approximation was rejected by the user and removed. Current implementation uses a self-contained pfUI-style `zoomfade`: a duplicate of the current icon expands and fades using pfUI's same per-frame fade/scale formula, then repeats for the BoP presentation lifetime. There is no pfUI runtime dependency.
- Vanilla `PlaySoundFile` cannot stop/fade an individual custom file, and ClassicAPI does not provide a per-file stop/fade backport. The uploaded source was therefore converted at `630676377e2c7ad3ce5a2219ee0dd31a4a0acb5a` into rank-specific PCM 16-bit mono 44.1 kHz WAVs and the MP3 source was removed:
  - spell 1022 / rank 1: `artwork/cena_r1.wav`, 6.5 s, fade from 6.0-6.5 s;
  - spell 5599 / rank 2: `artwork/cena_r2.wav`, 8.5 s, fade from 8.0-8.5 s;
  - spell 10278 / rank 3: `artwork/cena.wav`, 10.5 s, fade from 10.0-10.5 s.
- The verified client aura determines the rank locally. Icon/glow lifetime is 6/8/10 s respectively; the matching audio continues only through its baked 0.5-second fade tail. The wire protocol remains `BOP:<recipient>`.
- Dev-only `/wg debug discover|ring|off|state|clear` exercises local state/UI paths but does not prove PARTY/RAID transport.
- Dev-only `/wg debug cena [1|2|3]` is implemented (rank 3 when omitted) and is intentionally mode-agnostic on `dev`: it must work while the tester is in either `/wg ringer` or `/wg client`. It calls the same `StartBopPresentation` owner used by a real verified BoP, supplying only a synthetic local icon and selected BoP spell ID. It therefore exercises the real icon position/size, proc glow, rank lifetime and WAV selection while intentionally bypassing network/cast/aura authentication; it does not test those gates. This debug exception does not relax the real ringer -> client BoP invariant.

## Recent Relevant Commits
- `65ddb913d1ee3d88de2cfbbda7a31d665311364f` — replace rejected action-button border pulse with repeated pfUI-style `zoomfade` icon animation; sound, placement, rank timing and real BoP gating unchanged.
- `097483afb2fdc4dafdb00df4ebc4f122f0f04c33` — remove the debug-only client-mode guard so Cena presentation preview works while testing in `/wg ringer`; real BoP ringer/client gating is unchanged.
- `a225fe3dfa81543f3a1ffe8d824fcd12eea02a8e` — document the mode-agnostic dev-debug exception before implementation.
- `c06230493568520aa3c6735ef88af1a3becdca3e` — add localized help/status strings for the Cena presentation debug command.
- `a5576165e930e8e7e131a8b1a7c3c1dbfe646c3c` — add `/wg debug cena [1|2|3]`, routed through the real `StartBopPresentation` path.
- `e43537ff67da1b6cbea6cfdb97e1645911d52cc8` — document the debug-path contract before implementation.
- `75e47b4e246cb42884421934061af61d91a5e5f8` — remove the one-shot Lua 5.0.2 checker workflow after successful validation.
- `3fa99999fdc6862ae384482dcad9501e0c2dc616` — select Cena sound/presentation duration from the verified BoP rank.
- `91ef18cf0569d99f3353657006449174e6452ebe` — remove the one-shot audio conversion workflow after conversion.
- `630676377e2c7ad3ce5a2219ee0dd31a4a0acb5a` — convert the uploaded source into the three rank-timed WoW WAV assets and remove the MP3 source.
- `2096eea6c50985eb7c3f0020281b8e35d1f730b1` — user upload of the intended Cena MP3 source.
- `af5a03f98cafb7c3424bcefe2551ffe64fa5db94` — VanillaTemplate workflow migration; documentation-only, with runtime files unchanged from `597b076d2c3df4cd35c9dca52f517538b728c604`.
- `597b076d2c3df4cd35c9dca52f517538b728c604` — runtime implementation baseline for the current `0.1.10-dev` test build.
- `5b234923f9e3f416c69178669989fa3f6ea7e3cf` — add `artwork/cena.wav`.
- `e4696b7780176fccf8cb7922858839ea103a7eff` — implement Blessing of Protection/Cena presentation.
- `670e081b2ad23cda64122006999c265ae778fd9c` — bump development version to `0.1.10-dev`.
- `95107863bde6447fb4b1d731208bb595fb8d35ee` — add on-demand remote Ring Bell position refresh.
- `7d21ab0189db669cc8a294f7a400deed048fe397` — refine Ring Bell range and sender controls.

## Completed / User-Verified
- Directional target geometry and the tuning values recorded above were user-tested in WoW 1.12.1.
- Settings revision `2` one-time reset and subsequent persistence were user-verified.
- Stable `0.1.8` at `889a4a5daf1807e7a104b3eae413d26aa3468249` was exercised in the real two-client gift use: cross-client discovery, PARTY/RAID addon-message transport, remote ring delivery, and recipient cancellation worked.
- The earlier solo client pass also exercised local ringer/client UI state, `gaiasbell.wav`, directional/distance placement, ring-off, and target-to-cancel behavior without reported Lua errors.
- Approved runtime assets include `artwork/WanderingGaia_BellSwing_256x64.tga` and `artwork/gaiasbell.wav`.
- Real two-client `0.1.10-dev` Ring Bell refinement pass: user reports the complete Ring Bell test set working as expected, including at extreme distances. This verifies mirrored sender-control placement, active/inactive animation behavior, left re-ring/throttle behavior, immediate right-click stop, long-range position loss/refresh behavior, `POSQ`/`POS` recovery, and return to live positioning in the target environment.

## Implemented / Awaiting Runtime Test
- The dev-only `/wg debug cena [1|2|3]` presentation test is implemented and statically/compiler checked. The earlier border-pulse visual was user-exercised and rejected; the replacement pfUI-style `zoomfade` visual has not yet been user-tested.
- The 0.1.10 BoP/Cena slice is implemented but has not been exercised in game:
  - successful-cast gating and negative cast-result handling;
  - discovered-client/ringer/group/recipient checks;
  - matching-aura caster verification;
  - rank-aware icon/glow/sound presentation: 6/8/10-second visual lifetime with matching 6.5/8.5/10.5-second audio assets and final 0.5-second baked fade.
- Ring Bell verification is complete; the remaining `0.1.10-dev` runtime debt is the BoP/Cena slice. Static inspection or the presence of `cena.wav` is not runtime verification.

## Static / Automated Checks
- 0.1.9 Ring Bell audit confirmed the documented mirrored control placement, active-only animation, 3.14-second per-recipient re-ring throttle, immediate right-click stop, local-position-first behavior, one-per-second `POSQ`, and active-ring-gated `POS` replies.
- Current 0.1.10 code has no newly introduced `RegisterAddonMessagePrefix`, `C_ChatInfo`, `C_Timer`, or `string.match` dependency.
- All current `L.*` references resolve in `locales/enUS.lua`.
- Approximate top-level local count is 142, below Lua 5.0's 200-local function/chunk limit.
- Audio conversion workflow read the source as 12.64 s MP3 and verified all generated files with `ffprobe`: PCM `pcm_s16le`, mono, 44100 Hz, 16 bits/sample, durations exactly 6.500000 / 8.500000 / 10.500000 seconds.
- Runtime diff `3fa99999...` was statically reviewed: rank selection is derived from the same ClassicAPI aura that already passed sender verification; `BOP:<recipient>` communication and success/failure gating are unchanged.
- Current code has no `RegisterAddonMessagePrefix`, `C_ChatInfo`, `C_Timer`, or `string.match` dependency; all 61 current `L.*` references resolve; approximate top-level local declaration count remains 142.
- A verified official Lua 5.0.2 source archive (SHA-256 `a6c85d85f912e1c321723084389d63dee7660b81b8292452b190ea7190dd73bc`, matching VanillaTemplate's checker source) was built and `luac -p` passed on the current addon Lua tree in Actions run `36027072530`.
- The temporary checker workflow was removed after the pass; no persistent GitHub Actions workflow was added. Static/compiler checks are not an in-game test.
- After adding `/wg debug cena`, static review again found no modern API regressions or unresolved locale references, top-level local declarations remained 142, and the real verified Lua 5.0.2 `luac -p` pass succeeded in Actions run `36028531820`. Both temporary checker files were then removed.
- After removing the debug-only client-mode guard, static review again found no modern API regressions or unresolved locale references, top-level local declarations remained 142, and the real verified Lua 5.0.2 `luac -p` pass succeeded in Actions run `36028967511`. The temporary workflow was removed immediately afterward.
- After replacing the border pulse with the pfUI-style `zoomfade`, static review found no modern API regressions or unresolved locale references, top-level local declarations remained 142, the old `UI-ActionButton-Border`/`glowCycle` path was absent, and the real verified Lua 5.0.2 `luac -p` pass succeeded in Actions run `36031964090`. The temporary workflow was removed immediately afterward.

## Current Issues
- The 0.1.9 Ring Bell refinement delta now has real two-client runtime evidence, including extreme-distance behavior. The 0.1.10 BoP/Cena delta still has no runtime evidence.
- A ring that begins while the ringer is already outside usable ClassicAPI position range has no pre-existing endpoint; it uses the configured non-directional origin fallback until usable local/remote position becomes available.
- Rank-specific audio conversion and runtime selection are complete. The remaining BoP/Cena issue is runtime validation only.

## Testing

### Last Runtime Test
- Version/commit: `0.1.10-dev`; branch head at the test checkpoint was `af5a03f98cafb7c3424bcefe2551ffe64fa5db94`, whose runtime files are unchanged from implementation baseline `597b076d2c3df4cd35c9dca52f517538b728c604`.
- Passed: real two-client Ring Bell refinement set, reported working as expected even across extreme distances. This covers mirrored sender-bell placement, active/inactive animation, left re-ring/throttle, immediate right-click stop, long-range position handling, `POSQ`/`POS`, and recovery to live positioning.
- Failed: none reported for the Ring Bell pass.
- Not tested in this result: the 0.1.10 BoP/Cena positive and negative paths.

### Next Runtime Test
First do the local presentation pass on the current `0.1.10-dev` runtime while staying in whichever mode is convenient for testing (including `/wg ringer`):
1. Run `/wg debug cena 1`, `/wg debug cena 2`, and `/wg debug cena 3` (plain `/wg debug cena` is rank 3).
2. Verify the icon is 64 px at X `-200` / Y `0`, the repeated pfUI-style `zoomfade` pulse matches the expected action-button effect, the correct sound plays, visual lifetime is about 6/8/10 s, and each sound fades over the following final 0.5 s.
3. This local debug pass validates presentation only; it does not validate cast success, addon transport, ringer identity or aura-caster authentication.

Then continue the real two-client `0.1.10-dev` pass on WoW 1.12.1 with ClassicAPI on both clients:
1. Positive path for each available BoP rank from `/wg ringer` to a positively discovered client:
   - rank 1 / 1022: icon+glow for about 6 s; `cena_r1.wav` fades over 6.0-6.5 s;
   - rank 2 / 5599: icon+glow for about 8 s; `cena_r2.wav` fades over 8.0-8.5 s;
   - rank 3 / 10278: icon+glow for about 10 s; `cena.wav` fades over 10.0-10.5 s.
2. Confirm icon placement remains X `-200` / Y `0` and the proc-style glow/sound begin only after the verified successful BoP reaches the client.
3. BoP negatives: failed cast, interrupted cast, another paladin's BoP, non-ringer sender, wrong/non-client recipient, and mismatched aura caster must produce no presentation.
4. Record each observed runtime outcome separately from static/compiler checks before any release work.

## Planned / Next Work
- Locally exercise the implemented dev-only `/wg debug cena [1|2|3]` presentation test before the real two-client pass.
- Complete the BoP/Cena portion of the documented two-client pass and record exact results against the tested commit.
- Fix only demonstrated failures or regressions, then rerun the affected test.
- If the 0.1.10 runtime delta is accepted, prepare release only after explicit release work begins; do not silently promote from the current testing step.
- Runtime-test the rank-aware audio/visual timing and the existing BoP positive/negative gating before release.

## Deferred / Out of Scope
- Geometry retuning unless the runtime test reveals a real regression.
- Options UI.
- Minimap button.
- New frameworks/libraries.
- Broader public/multi-user security model.

## Release / Promotion Notes
- Latest stable runtime release is `0.1.9` at `09f6dd18bd56faca23e0336a463e6969bba6849e`.
- Current `main` head is `8e4926cdb30042d2e025209262236bbce5f8fa2a` and still reports `0.1.9`. The later main commits are presentation-only.
- `main` and `dev` are divergent histories; release prep must compare them and preserve intended main content rather than replacing main blindly.
- Main-only/presentation content to preserve:
  - current main `README.md` containing the artwork presentation;
  - `artwork/wanderinggaia.png`;
  - `artwork/wanderinggaia2.png`.
- Stable builds have historically excluded the integrated solo debug harness and development-status documents; preserve that release convention unless explicitly changed.
- Runtime assets that must remain present when relevant are `artwork/WanderingGaia_BellSwing_256x64.tga`, `artwork/gaiasbell.wav`, and, if the BoP/Cena slice is accepted, `artwork/cena_r1.wav`, `artwork/cena_r2.wav`, and `artwork/cena.wav`.
- Known validation debt accepted for the already released 0.1.9: its new sender-control/long-range refinement delta was promoted without a separate two-client verification pass.
- No equivalent validation debt has been accepted for a future 0.1.10 release.
- External/runtime prerequisites for the next pass: two grouped WoW 1.12.1 clients with ClassicAPI; the ringer must be able to cast Blessing of Protection for the BoP path.

## Exact Next Step
While remaining in `/wg ringer`, run `/wg debug cena 1`, `/wg debug cena 2`, and `/wg debug cena 3` and judge the replacement pfUI-style repeated `zoomfade` pulse against the action-button animation you expect. Also confirm icon placement/size and the already-good sound/fade behavior. Record that local runtime result here before the real two-client BoP positive/negative gating tests.
