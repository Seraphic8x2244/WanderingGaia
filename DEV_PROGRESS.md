# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.8-dev`
- Latest dev handoff/test commit before release prep: `e55c712e1ce806cf0412732057deabc602eb7393`.
- Release-prep documentation commit: `f7c403e491077b86dd2a4b289b4fa89d7abe81c2`.
- Stable `main` release commit: `889a4a5daf1807e7a104b3eae413d26aa3468249` (`0.1.8`).
- Stable promotion PR: `#1`, squash-merged.
- Ring Bell implementation commit: `11f53ec97031b7f9463c8224d327110e0980cef4`.
- Ring Bell locale commit: `1bbc32e33ce61dbb2311c8f8edb7fba8af4d6116`.
- Solo-test plan/handoff pre-build commit: `d63ffc9f838bd4c7e522d59de42c0ea6e8d98afa`.
- User-uploaded runtime sound commit: `51f02c970028a8048e77877edce73053084730ad`.
- Goal: refine the now-successful real two-client Ring Bell behavior. Blessing of Protection/Cena remains a later slice.

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

## Next Dev Slice — 0.1.9-dev
- User reports the real stable `0.1.8` surprise worked perfectly.
- At sufficiently long range, ClassicAPI `UnitPosition(ringer)` becomes unavailable because the remote unit leaves the client-visible object set. Current runtime then falls back to the configured visual origin.
- Requested compromise: cache each active ringer's last known world position/map. If live ringer position disappears, keep reading the recipient's current position/facing and recompute bearing toward that cached endpoint; force stale-position presentation to the outer-distance end of the existing curve. Resume live position automatically when available again, and discard stale position across map/instance mismatch.
- Sender control bell changes:
  - animate while the currently targeted recipient has an active outgoing ring;
  - stop on a static frame when inactive;
  - move it above screen centre by the same magnitude that the configured visual origin/deadzone is shifted below centre (default Origin Y = -10% -> control at +10% screen height);
  - left click sends/rerings `RING:1`;
  - left-click ring sends are throttled only by `2 * gaiasbell.wav` duration (processed WAV duration ~1.57s -> ~3.14s);
  - right click sends `RING:0` immediately with no stop throttle.
- Preserve independent per-recipient state and all already-tested recipient behavior, including: a recipient already targeting the ringer when a new ring arrives must still receive the ring; only a later target-change onto the ringer cancels it.

## Deferred
- Any geometry retuning unless the solo test reveals a real regression.
- Real two-client/cross-client validation until after the surprise is delivered or a safe unrelated second client becomes available.
- Blessing of Protection / John Cena feature.
- Options UI, minimap button, frameworks/libraries, public/multi-user security model.

## Exact Next Step
Implement `0.1.9-dev` on `dev` only: last-known remote-position fallback at outer distance, active/inactive sender-bell animation, mirrored upward sender-bell placement, and left-ring/right-stop controls with only the requested ~3.14s rerink throttle. Preserve the real Vanilla communication path and tested geometry. Then perform static Lua 5.0/API checks and user-test with the real two-client setup before any stable promotion.
