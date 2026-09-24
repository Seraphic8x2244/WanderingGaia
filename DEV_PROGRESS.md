# Development Progress

## Resume Status — 2026-09-24
- Branch: `dev`; resume baseline/head before this session's edits: `3c86439694b712ebfebb8e3a5ba5f66f7bf66852`.
- Version: `0.1.9-dev`.
- Stable runtime baseline remains `0.1.9` at `09f6dd18bd56faca23e0336a463e6969bba6849e`; current `main` is two presentation-only commits ahead (README plus `artwork/wanderinggaia2.png`), with head `8e4926cdb30042d2e025209262236bbce5f8fa2a`.
- Completed this session before implementation: confirmed supplied `dev` handoff exactly matches branch head; confirmed the documented Ring Bell 0.1.9 protocol/refinement code is the implementation baseline to audit; confirmed no Cena audio asset is currently present in repo/conversation files.
- Runtime verification status: the repository handoff still records the 0.1.9 two-client refinement pass as awaiting a separate in-game verification. This session can statically verify those paths but must not claim a real two-client pass without user/runtime evidence.
- Untested/new work: Blessing of Protection/Cena slice is not yet implemented or in-game tested at this checkpoint.
- Deferred remains unchanged: geometry retuning, options/minimap/framework work, and broader public/multi-user security design.
- Exact next step: statically audit the 0.1.9 sender-bell/re-ring/right-click/POSQ/POS paths against the documented behavior, then implement only the documented BoP/Cena slice on `dev`; preserve the real two-client runtime-verification distinction in the handoff.

## Current
- Branch: `dev`
- Version: `0.1.10-dev`
- Resume/status checkpoint: `9ba81c947850a881d4e538cc98a019f40b0548a4`.
- Blessing of Protection/Cena implementation: `e4696b7780176fccf8cb7922858839ea103a7eff`.
- `0.1.10-dev` version bump: `670e081b2ad23cda64122006999c265ae778fd9c`.
- Latest dev handoff/test commit before release prep: `e55c712e1ce806cf0412732057deabc602eb7393`.
- Release-prep documentation commit: `f7c403e491077b86dd2a4b289b4fa89d7abe81c2`.
- `0.1.9-dev` Ring Bell refinement implementation: `7d21ab0189db669cc8a294f7a400deed048fe397`.
- Stale-position lifetime cleanup: `3c92f85ed07cc16a9147ffed710d570024ebfe86`.
- `0.1.9-dev` version bump: `694881e735323863b6597f74647db31d72af3f1d`.
- On-demand remote-position protocol implementation: `95107863bde6447fb4b1d731208bb595fb8d35ee`.
- Stable `main` release commit: `09f6dd18bd56faca23e0336a463e6969bba6849e` (`0.1.9`).
- Previous stable `0.1.8` release commit: `889a4a5daf1807e7a104b3eae413d26aa3468249`.
- Stable `0.1.9` promotion PR: `#2`, squash-merged.
- Previous stable `0.1.8` promotion PR: `#1`, squash-merged.
- Ring Bell implementation commit: `11f53ec97031b7f9463c8224d327110e0980cef4`.
- Ring Bell locale commit: `1bbc32e33ce61dbb2311c8f8edb7fba8af4d6116`.
- Solo-test plan/handoff pre-build commit: `d63ffc9f838bd4c7e522d59de42c0ea6e8d98afa`.
- User-uploaded runtime sound commit: `51f02c970028a8048e77877edce73053084730ad`.
- Goal: runtime-test the statically checked 0.1.9 Ring Bell refinements and the newly implemented 0.1.10 BoP/Cena slice without changing the proven Ring Bell protocol/geometry.

## Completed / User-Verified
- WoW 1.12.1 / Interface 11200 / Lua 5.0 baseline.
- Directional target preview with ClassicAPI positions/facing.
- Ellipse placement model and promoted tuning:
  - `minrange=0`
  - `origin=0:-10`
  - `inner=5:15`
  - `outer=40:60:25`
  - `curve=0:0,10:20,20:60,44:80,80:100`
  - `size=64:16`
  - `smooth=50`
- Settings revision `2` one-time reset: user verified old tuning resets once to the promoted defaults (including Outer Up = 60) and later edits persist across restart.
- Approved bell spritesheet is committed as `artwork/WanderingGaia_BellSwing_256x64.tga`.
- Chosen CC0 bell source was processed to mono 44.1 kHz 16-bit PCM at -4.5 dBFS and user uploaded it as `artwork/gaiasbell.wav`.

## Implemented / Awaiting In-Game Test
### Ring Bell runtime
- Runtime session starts in **client mode**.
- `/wg ringer` enters ringer/control mode.
- `/wg client` returns to client mode.
- Client and ringer modes are mutually exclusive.
- Vanilla communication mirrors the proven `pfUI_TankIcons` pattern:
  - `SendAddonMessage(prefix, payload, "RAID"/"PARTY")`
  - `CHAT_MSG_ADDON`
  - legacy `arg1` prefix, `arg2` payload, `arg4` sender
  - no `RegisterAddonMessagePrefix` / `C_ChatInfo`.
- Wire messages are explicit:
  - `Q` discovery query
  - `MODE:C` client announcement
  - `MODE:R` ringer announcement
  - `RING:1:<recipient>`
  - `RING:0:<recipient>`
  - `CANCEL:<ringer>`
- Ringer tracks positively discovered client-mode group members.
- Sender control bell appears only while targeting a discovered client.
- Clicking the sender bell toggles that target's ring on/off.
- Outgoing ring state is keyed per recipient; no single-recipient restriction, forced replacement, arbitrary cooldown, or other artificial ringing guardrail.
- Incoming ring state is keyed per sender and can display separate simultaneous bell frames.
- Incoming `RING:1` plays `Interface\\AddOns\\WanderingGaia\\artwork\\gaiasbell.wav`.
- Incoming rings resolve the actual addon-message sender to a party/raid unit and reuse the existing tested geometry.
- The geometry formula itself was not retuned; it was parameterized from hardcoded `"target"` to an arbitrary unit token.
- Without directional data, an incoming ring falls back to the configured visual origin rather than disappearing.
- A client cancels an active incoming ring by targeting the active ringer; cancellation is sent back so that ringer clears its outgoing state.
- Roster/mode changes clean stale state rather than leaving orphaned rings.

### Solo dev simulation
- The intended recipient must not be used for pre-gift testing.
- Dev-only commands exercise the same local discovery/ring/cancel state handlers used by real addon messages:
  - `/wg debug discover` — while in ringer mode, treat the current target as a discovered client.
  - `/wg debug ring` — while in client mode, simulate an incoming ring from the current target.
  - `/wg debug off` — simulate ring-off from the current target.
  - `/wg debug state` — print current mode/target/discovery/outgoing/incoming state.
  - `/wg debug clear` — clear solo simulation state.
- Simulation deliberately does not claim to test the actual PARTY/RAID transport.

## Static Checks
- `WanderingGaia.lua` has no `RegisterAddonMessagePrefix`, `C_ChatInfo`, `C_Timer`, `string.match`, or other newly introduced communication API usage found by the compatibility scan.
- All new `L.*` references are present in `locales/enUS.lua`.
- Single-file top-level local declaration count remains below the Lua 5.0 chunk-local limit.
- No GitHub Actions/CI workflow exists; static inspection is not an in-game test.

## Gift Build Preparation
- Gift/stable build preparation is explicitly authorized by the user.
- Preserve the confirmed cancellation edge case: if the client is already targeting the ringer when a new ring arrives, the ring must still appear and remain active; cancellation requires a later `PLAYER_TARGET_CHANGED` onto that ringer.
- Before promotion, re-audit the real PARTY/RAID protocol against `pfUI_TankIcons`, remove all solo debug commands/state from the distributable build, retain `artwork/gaiasbell.wav`, and keep the user-tested geometry unchanged.
- Stable target is `0.1.8` on `main`; `DEV_GUIDE.md`, `DEV_PROGRESS.md`, and dev-only simulation must not ship.

## Stable 0.1.8
- Stable `0.1.8` is now on `main`.
- Stable tree contains only distributable runtime files/assets plus README; `DEV_GUIDE.md`, `DEV_PROGRESS.md`, and the solo `/wg debug` harness are excluded.
- Stable TOC is `Interface: 11200`, title `WanderingGaia`, version `0.1.8`.
- Runtime assets verified on `main`: `artwork/WanderingGaia_BellSwing_256x64.tga` and `artwork/gaiasbell.wav`.
- Post-merge static checks confirm client mode defaults on, legacy Vanilla `SendAddonMessage` + `CHAT_MSG_ADDON`/legacy args are intact, and target-to-cancel is only invoked from `PLAYER_TARGET_CHANGED`.
- Therefore a client who is already targeting the ringer when `RING:1` arrives still receives the ring; cancellation requires a later target-change event onto that ringer.

## Current Issues / Untested
- `0.1.8-dev` has now passed the planned solo in-game test with no reported Lua errors.
- Real cross-client discovery, PARTY/RAID addon-message transport, remote ring delivery, and recipient cancellation have now been exercised successfully in the actual gift use.
- Sender control bell position (`UIParent CENTER`, Y -145, 42 px) is provisional until the solo UI test.
- For the solo incoming-ring simulation, the simulated sender is the current target unit. If you target away, the debug visual falls back to the configured origin until you retarget/cancel; this does not affect real group-unit resolution.
- Native 1.12.1 has no camera pitch/projection data for true vertical projection; Z remains radial-distance-only as before.

## Last Test — Solo Client
- User-tested `0.1.8-dev` in WoW successfully.
- Ringer mode, simulated client discovery, target-gated sender bell visibility, and click-on/click-off outgoing state behaved as designed.
- Client-mode simulated incoming ring played `gaiasbell.wav` and used the existing directional/distance geometry as intended.
- Simulated ring-off removed the incoming presentation.
- Target-to-cancel behaved as designed: after `/wg debug ring` on an NPC, deselecting caused the documented debug-only fallback at the configured origin; reselecting the same simulated sender cancelled the bell.
- Everything else in the planned solo test behaved as described.
- This confirms the local UI/state/sound/geometry/cancel paths. It does not validate real PARTY/RAID addon-message delivery between two clients.

## Implemented / Awaiting Test — 0.1.9-dev
- User reports the real stable `0.1.8` surprise worked perfectly, including real discovery and PARTY/RAID transport.
- Long-range fallback now caches the active ringer's last known west/north/Z/map while live `UnitPosition(ringer)` data is available.
- When the ringer leaves ClassicAPI's visible-object range:
  - the cached ringer endpoint freezes;
  - the recipient's current position and facing remain live;
  - bearing is recomputed continuously from the recipient's current position to the cached ringer endpoint;
  - the bell is forced to the outer ellipse / far-size end of the existing geometry;
  - live ringer position resumes automatically as soon as `UnitPosition` returns again;
  - cached position is discarded when the ring stops/cancels or the recipient changes map/instance.
- If a ring starts while the ringer is already too far away and no current-ring cache exists yet, the existing non-directional origin fallback remains unavoidable until live position becomes available.
- Sender control bell:
  - is positioned above screen centre by the mirror of the configured visual-origin Y offset (default Origin Y = -10% -> control at +10% UI height);
  - animates only while the currently targeted recipient has an active outgoing ring;
  - returns to frame 1 and stops animating when inactive;
  - registers both `LeftButtonUp` and `RightButtonUp` using the Vanilla button API;
  - left click sends `RING:1` even when already active, allowing a re-ring;
  - left-click sends are throttled per recipient to `2 * 1.57s = 3.14s`;
  - right click clears local outgoing state and sends `RING:0` immediately with no stop throttle.
- Existing independent per-recipient ring state remains intact.
- Existing recipient cancellation semantics are unchanged: already targeting the ringer when `RING:1` arrives does not suppress the ring; only a later `PLAYER_TARGET_CHANGED` onto that ringer cancels it.

### On-demand remote position refresh
- Implemented as optional backward-compatible messages:
  - `POSQ:<ringer>` — an actively rung client requests the named ringer's current player position.
  - `POS:<recipient>:<map>:<west>:<north>:<z-or-n>` — the requested ringer replies group-wide; only the named recipient consumes it, and `arg4` remains the authoritative ringer identity.
- Receiver behavior implemented:
  - local `UnitPosition(ringer)` remains primary and produces zero position-request traffic while available;
  - first local-position failure for an active ring requests immediately;
  - continued failure sends at most one `POSQ` per second per active ringer;
  - newest local/remote position updates the existing cached endpoint between replies;
  - request timing resets immediately when local `UnitPosition(ringer)` works again;
  - request state/cache clear when the ring ends.
- Ringer behavior implemented:
  - replies only for a real grouped sender, only in ringer mode, only when `POSQ` names the local player, and only when that requester is currently present in `outgoingRings`;
  - reads only `UnitPosition("player")` for the reply;
  - response names the requester as recipient, preserving independent simultaneous rings.
- Remote `POS` data is consumed only by an active incoming ring from the authoritative addon-message sender and only when its payload recipient matches the local player.
- Map mismatch is rejected by the existing geometry/cache path; the bell remains non-directional until a usable same-map endpoint is available.
- `0.1.8` and earlier clients ignore the unknown `POSQ`/`POS` messages and keep their existing behavior.
- Static checks: no modern comm APIs, no missing locale keys, existing `RING`/`CANCEL` protocol unchanged, approximately 128 top-level chunk locals, no CI available.

## Stable 0.1.9 Promotion
- Stable `0.1.9` promotion is explicitly authorized by the user despite the new `0.1.9-dev` refinements not yet receiving a separate two-client verification pass.
- Promotion must preserve `main`'s artwork-only README and `artwork/wanderinggaia.png`.
- Build stable runtime from current `dev`, strip the solo debug harness, use stable title/version `WanderingGaia` / `0.1.9`, and leave development docs off `main`.
- Promote via a release branch based on current `main` so main-only presentation assets are retained.

## Verification Status — 0.1.9 Ring Bell Refinements
- Static audit completed on 2026-09-24 against the exact 0.1.9 refinement implementation:
  - sender control position still mirrors configured Origin Y;
  - active-target sender bell animation remains isolated from inactive targets;
  - left re-ring remains per-recipient throttled at 3.14 seconds;
  - right-click still clears/sends `RING:0` immediately with no stop throttle;
  - local `UnitPosition(ringer)` remains primary;
  - `POSQ` starts only after local position loss and is capped at one request/second per active ring;
  - ringer `POS` replies remain gated to the corresponding active outgoing ring.
- The final 0.1.10 diff does not rewrite those Ring Bell paths; after the pre-implementation checkpoint, only `WanderingGaia.lua` BoP/Cena additions and the TOC version changed.
- This is **not** a real two-client in-game verification. The repository still has no user/runtime evidence for a separate 0.1.9 two-client refinement pass, and `DEV_GUIDE.md` explicitly forbids treating static inspection as user testing.

## Implemented / Awaiting In-Game Test — 0.1.10-dev Blessing of Protection / Cena
- Implemented on `dev` at `e4696b7780176fccf8cb7922858839ea103a7eff` after the static 0.1.9 Ring Bell audit. A true two-client 0.1.9 refinement verification was not possible in this session and remains separately unverified.
- Scope is strictly ringer/admin -> discovered client:
  - caster must currently be in `/wg ringer` mode;
  - recipient must be a positively discovered WanderingGaia client;
  - receiver must currently be in client mode;
  - receiver should accept the event only from a grouped sender currently known as a ringer/admin, with `arg4` as authoritative sender identity.
- Both users have ClassicAPI. Prefer ClassicAPI spellcast/aura events over button-press inference.
- Successful-cast gating implemented:
  - `UNIT_SPELLCAST_SENT` records only BoP ranks 1022/5599/10278 cast by the local ringer at a currently discovered grouped client, retaining target + castGUID + spellID;
  - `UNIT_SPELLCAST_INTERRUPTED`, `UNIT_SPELLCAST_FAILED`, and `UNIT_SPELLCAST_FAILED_QUIET` clear the matching pending cast without sending;
  - only a matching `UNIT_SPELLCAST_SUCCEEDED` while the target is still a discovered grouped client sends `BOP:<recipient>`.
- Receiver gating implemented:
  - ordinary addon-message validation still rejects self/non-group senders and treats `CHAT_MSG_ADDON arg4` as authoritative sender identity;
  - clients track grouped peers that positively announce ringer mode through the existing `MODE:R` / ringer `Q` discovery flow;
  - `BOP:<recipient>` is accepted only in client mode, only for the local player, and only from a currently known grouped ringer;
  - presentation waits up to 1.5 seconds for ClassicAPI aura propagation;
  - the player BoP aura must be one of ranks 1022/5599/10278 and its ClassicAPI `sourceUnit` or `sourceGUID` must resolve to the same ringer who sent the message.
- Existing Ring Bell `Q` / `MODE:*` / `RING:*` / `CANCEL` / `POSQ` / `POS` wire messages are otherwise unchanged.
- Presentation implemented:
  - 64 px BoP icon, using the aura icon with `Spell_Holy_SealOfProtection` fallback;
  - anchored at `UIParent CENTER`, X = `-200`, Y = `0`;
  - Vanilla-era additive `Interface\\Buttons\\UI-ActionButton-Border` glow, pulsed around the icon without retail-only overlay-glow APIs;
  - `PlaySoundFile("Interface\\AddOns\\WanderingGaia\\artwork\\cena.wav")` starts with the visual;
  - visual/glow lifetime is exactly 10 seconds.
- Expected negative cases are enforced in code: failed/interrupted attempts do not send; undiscovered/non-group/wrong recipients do not send; non-client/wrong-recipient/non-ringer messages do not present; a BoP aura from a different caster does not satisfy verification.
- Runtime prerequisite still missing: `artwork/cena.wav` is referenced but is not currently present in the repository or available conversation files. The sound path therefore cannot be tested yet.
- Static checks after implementation:
  - no `RegisterAddonMessagePrefix`, `C_ChatInfo`, `C_Timer`, or other modern communication/timer dependency introduced;
  - approximately 142 top-level locals, still below the Vanilla Lua chunk-local limit;
  - final implementation diff is limited to `WanderingGaia.lua` plus the `0.1.10-dev` TOC bump.
- Entire 0.1.10 BoP/Cena slice remains **awaiting in-game two-client testing**.

## Deferred
- Any geometry retuning unless the solo test reveals a real regression.
- Real two-client/cross-client validation until after the surprise is delivered or a safe unrelated second client becomes available.
- Options UI, minimap button, frameworks/libraries, public/multi-user security model.

## Exact Next Step
Add the intended `artwork/cena.wav` asset, then run a real two-client `0.1.10-dev` pass. First re-check the inherited 0.1.9 Ring Bell refinements (sender-bell mirrored position/animation, left re-ring throttle, immediate right-click stop, and long-range `POSQ`/`POS`). Then test BoP from the ringer to a positively discovered client: successful BoP should produce the verified BoP icon at X -200 / Y 0, Vanilla action-button-style proc glow and Cena audio for the intended 10-second presentation; failed/interrupted BoP, a different paladin's BoP, non-ringer sender, wrong/non-client recipient, and mismatched aura caster must produce no presentation. Record the actual in-game outcomes separately from static checks before any stable promotion.
