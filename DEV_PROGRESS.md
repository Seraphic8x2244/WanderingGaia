# Development Progress

> Live project-development context for a fresh chat. Keep this current and concise. Remove or compress superseded detail once it no longer affects future work.

## Current
- Branch: `dev`
- Version: `0.1.10-dev`
- Development/runtime head verified before this documentation-only workflow migration: `597b076d2c3df4cd35c9dca52f517538b728c604`. The migration itself must not change runtime files.
- Stable runtime baseline: `0.1.9` at `09f6dd18bd56faca23e0336a463e6969bba6849e`.
- Current `main` head: `8e4926cdb30042d2e025209262236bbce5f8fa2a` (still `0.1.9`; later commits are presentation-only).
- Goal: complete the remaining real two-client verification for the 0.1.10 BoP/Cena slice, then fix only demonstrated runtime issues before any release work.
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
- BoP presentation is a 64 px aura icon at `UIParent CENTER`, X `-200`, Y `0`, with `Spell_Holy_SealOfProtection` fallback, pulsing additive `UI-ActionButton-Border` glow, `artwork/cena.wav`, and an exact 10-second lifetime.
- `artwork/cena.wav` is currently an original functional test cue (PCM 16-bit mono 44.1 kHz, 1.55 s). If a specific intended Cena recording is desired, replace it before release rather than treating the placeholder cue as that recording.
- Dev-only `/wg debug discover|ring|off|state|clear` exercises local state/UI paths but does not prove PARTY/RAID transport.

## Recent Relevant Commits
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
- The 0.1.10 BoP/Cena slice is implemented but has not been exercised in game:
  - successful-cast gating and negative cast-result handling;
  - discovered-client/ringer/group/recipient checks;
  - matching-aura caster verification;
  - icon/glow/sound presentation and 10-second lifetime.
- Ring Bell verification is complete; the remaining `0.1.10-dev` runtime debt is the BoP/Cena slice. Static inspection or the presence of `cena.wav` is not runtime verification.

## Static / Automated Checks
- 0.1.9 Ring Bell audit confirmed the documented mirrored control placement, active-only animation, 3.14-second per-recipient re-ring throttle, immediate right-click stop, local-position-first behavior, one-per-second `POSQ`, and active-ring-gated `POS` replies.
- Current 0.1.10 code has no newly introduced `RegisterAddonMessagePrefix`, `C_ChatInfo`, `C_Timer`, or `string.match` dependency.
- All current `L.*` references resolve in `locales/enUS.lua`.
- Approximate top-level local count is 142, below Lua 5.0's 200-local function/chunk limit.
- `artwork/cena.wav` was read back from GitHub and verified as RIFF/WAVE PCM format 1, mono, 44100 Hz, 16 bits/sample.
- No GitHub Actions/CI workflow exists. Static inspection is not an in-game test.

## Current Issues
- The 0.1.9 Ring Bell refinement delta now has real two-client runtime evidence, including extreme-distance behavior. The 0.1.10 BoP/Cena delta still has no runtime evidence.
- A ring that begins while the ringer is already outside usable ClassicAPI position range has no pre-existing endpoint; it uses the configured non-directional origin fallback until usable local/remote position becomes available.
- The current `cena.wav` is a functional cue, not a confirmed specific source recording.

## Testing

### Last Runtime Test
- Version/commit: `0.1.10-dev`; branch head at the test checkpoint was `af5a03f98cafb7c3424bcefe2551ffe64fa5db94`, whose runtime files are unchanged from implementation baseline `597b076d2c3df4cd35c9dca52f517538b728c604`.
- Passed: real two-client Ring Bell refinement set, reported working as expected even across extreme distances. This covers mirrored sender-bell placement, active/inactive animation, left re-ring/throttle, immediate right-click stop, long-range position handling, `POSQ`/`POS`, and recovery to live positioning.
- Failed: none reported for the Ring Bell pass.
- Not tested in this result: the 0.1.10 BoP/Cena positive and negative paths.

### Next Runtime Test
Continue the real two-client `0.1.10-dev` pass on WoW 1.12.1 with ClassicAPI on both clients:
1. BoP positive path: from `/wg ringer`, cast successful BoP on a positively discovered client. The client should show the verified BoP icon at X `-200` / Y `0`, pulsing Vanilla action-button-style glow, play `artwork/cena.wav`, and keep the presentation for 10 seconds.
2. BoP negatives: failed cast, interrupted cast, another paladin's BoP, non-ringer sender, wrong/non-client recipient, and mismatched aura caster must produce no presentation.
3. Record each observed runtime outcome separately from static checks before any release work.

## Planned / Next Work
- Complete the BoP/Cena portion of the documented two-client pass and record exact results against the tested commit.
- Fix only demonstrated failures or regressions, then rerun the affected test.
- If the 0.1.10 runtime delta is accepted, prepare release only after explicit release work begins; do not silently promote from the current testing step.
- If a specific Cena clip is desired, replace the functional cue and retest the sound path before release.

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
- Runtime assets that must remain present when relevant are `artwork/WanderingGaia_BellSwing_256x64.tga`, `artwork/gaiasbell.wav`, and, if the BoP/Cena slice is accepted, `artwork/cena.wav`.
- Known validation debt accepted for the already released 0.1.9: its new sender-control/long-range refinement delta was promoted without a separate two-client verification pass.
- No equivalent validation debt has been accepted for a future 0.1.10 release.
- External/runtime prerequisites for the next pass: two grouped WoW 1.12.1 clients with ClassicAPI; the ringer must be able to cast Blessing of Protection for the BoP path.

## Exact Next Step
Continue the real two-client `0.1.10-dev` pass with the BoP/Cena positive path and negative cases, then record those exact in-game outcomes here before any release work.
