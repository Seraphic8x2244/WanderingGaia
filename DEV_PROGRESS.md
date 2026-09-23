# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.7-dev`
- Current handoff head: `c02259ebf47a724ac3e395457b6cb97a62e91445`.
- `0.1.7-dev` one-time settings revision reset is user-verified: first load reset to the promoted defaults including `Outer Up = 60`, and a subsequent user change persisted across restart.
- Current defaults: `minrange=0 origin=0:-10 inner=5:15 outer=40:60:25 curve=0:0,10:20,20:60,44:80,80:100 size=64:16 smooth=50`.
- Settings revision `2` intentionally resets pre-0.1.7 saved tuning once, then normal persistence resumes.
- Goal: Build WanderingGaia as a small personal WoW 1.12.1 addon with a directional "ring bell" aid first, followed by the Blessing of Protection gag as a separate feature slice.

## Recent Commits
- `cd5ade125958b6611d61ca10ddf6fdda0e4e2b9b` - Record the 0.1.7 default-reset test handoff.
- `b0ef0a2dddbc526d97750b9a986d9b4fe36eb69d` - Bump WanderingGaia to 0.1.7-dev.
- `cb0da7e071dc48415b305097e541df9c5d7f5b12` - Set the tested tuning profile as defaults and add the one-time settings revision reset.
- `f42d1c08a29012c44d0332f3d234c781c0b72f8d` - Record the final tuning defaults and reset request before implementation.
- `21fdb0a1b583856a881603df1d70fc8c4fae07ed` - Bump WanderingGaia to 0.1.6-dev.
- `6d7edff9f2e9343c2aac7d5b82a922ce3314fce4` - Remove physical-screen and outer-vs-inner placement guardrails.
- `9291456eec4bf50315d1e0d15f168cb823cc3742` - Remove arbitrary tuning value caps from normalization.
- `a946c8e9137560db2038a7f758f481702701cd7a` - Document project rule: user-owned configuration values are not arbitrarily capped or silently clamped.
- `2b91e0e8762606598a00ab882c98b49c7adc2c05` - Bump WanderingGaia to 0.1.5-dev.
- `553016a2b10ecc60ddebec9583fd5e4ef1163f1a` - Split outer ellipse vertical tuning into independent Up/Down radii and migrate the old symmetric Y value.
- `95c6f45139f7f4dee04ba2cb3088dfbec56511ee` - Add asymmetric outer ellipse labels and diagnostics strings.
- `f6533f985df2019cfafa28f9c06311d7b8f48453` - Record asymmetric outer ellipse tuning request and positive first ellipse test.
- `49446d640b9bf658e98e08789919e3d2c166774f` - Bump WanderingGaia to 0.1.4-dev after ellipse geometry implementation.
- `4a1cec0ee602b27cefcd7230b071e306422e623d` - Replace rectangular bell limits with inner/outer ellipse geometry; make XYZ range automatic; preserve range-based size and curve.
- `84bef8dea24c0526c7586fd70a78c47f18c39933` - Add ellipse tuning and diagnostics strings.
- `90ca9ceae22618abf3b4cb30449b1684d9f978e9` - Record the requested ellipse-geometry implementation plan before code changes.
- `2e65805bd65ec25e92224ba4432c2ec3b24fc3e6` - Bump WanderingGaia to 0.1.3-dev after adding the configurable visual origin.
- `37790c48e979fef46f9b818da75342a000addad5` - Add configurable X/Y bell origin offsets while keeping outer deadzones fixed to the screen.
- `cf655202ba784b97c48baf8dd076bf4e1e6348cc` - Add visual-origin configuration and diagnostic strings.
- `fb11dc26a599fa8cb2e075bcec22b43ee19673e3` - Bump WanderingGaia to 0.1.2-dev and persist tuning settings with `WanderingGaiaDB`.
- `aad7fb62480eee8abaac772e8163f3a98450a191` - Add bell tuning controls, safe-area overlays, range sizing, optional smoothing/Z range, and coordinate diagnostics.
- `d5b041e99871a5e6ca2f9a13393e70bad81ba4b6` - Add tuning/configuration locale strings.
- `a14316e6776aaf640ef210bdf42b8aee1a60ea2f` - Record the 0.1.1 centre-anchor retest handoff.
- `dc758a92572f1c562a78fbf21971c6eaf215ddb0` - Bump WanderingGaia to 0.1.1-dev after direct UI-centre anchor fix.
- `82c479f0913e757464872b49ea3ff218dc4dc240` - Anchor bell directly to UIParent CENTER.

## Completed / Verified
- Repository initialized on `dev` for WoW 1.12.1 / Lua 5.0.
- Four-frame bell artwork is committed as PNG source plus 256x64 32-bit uncompressed TGA runtime texture.
- `0.1.1-dev` runtime result: user reports the direct-`UIParent CENTER` bell origin and DLL-provided direction behaviour work about as well as could reasonably be expected.
- Directional movement/bearing is user-verified as working well while rotating around a target.
- `0.1.2-dev` runtime result: user reports the config controls are good overall; the remaining usability gap was the inability to move the visual origin downward to match the apparent player position.
- Bell swing animation timing remains `0.07` seconds per sprite step and was deliberately not made configurable.
- `0.1.4-dev` first ellipse test: user reports the ellipse geometry removes the previous jitter and already feels intuitive.
- `0.1.7-dev` settings revision `2` is user-verified: old tuning reset exactly once to the promoted defaults, including `Outer Up = 60`, and later edits persisted across restart rather than resetting twice.

## Implemented / Awaiting Test
- `0.1.7-dev` asymmetric outer ellipse tuning model:
  - `Origin X (%)` / `Origin Y (%)` move the visual player-origin relative to true UI centre.
  - `Inner X/Y` are ellipse radii as percentages of screen width/height and define the character exclusion zone.
  - `Outer X` is the shared left/right radius; `Outer Up` and `Outer Down` independently define the upper/lower vertical travel radii.
  - the bell starts on the inner ellipse at the minimum-range end of the curve and interpolates toward the outer ellipse according to the existing five-point distance curve.
  - the effective inner boundary expands by half the current bell size and the effective outer boundary contracts by half the bell size, so the bell graphic itself respects the configured ellipses rather than only its centre point.
  - opening `/wg config` shows a translucent filled inner ellipse, a dotted outer ellipse and an origin cross/label.
  - range calculation always uses XYZ distance when both Z values are available; there is no longer a user-facing Z toggle. If Z is unavailable, the runtime falls back to 2D and `/wg coords` reports that fallback.
  - horizontal screen direction still uses the existing relative 2D bearing because camera pitch/projection data is not available.
  - range-based near/far bell sizing remains enabled and uses the same curve percentage.
  - smoothing remains configurable and defaults to 0%.
  - animation timing remains fixed at `0.07` seconds per sprite step.
  - settings persist in `WanderingGaiaDB`.
  - User-entered tuning values are no longer arbitrarily capped or silently reshaped; extreme values are preserved. Only the rendered bell size retains a positive floor because WoW frame dimensions must remain positive.
  - The user-tested profile is now the install/reset default: `minrange=0 origin=0:-10 inner=5:15 outer=40:60:25 curve=0:0,10:20,20:60,44:80,80:100 size=64:16 smooth=50`.
  - `SETTINGS_REVISION = 2` deliberately discards all older saved tuning once on first 0.1.7 load, writes these defaults, and records the revision so later reloads preserve user changes normally.
  - Copy settings exports `WGCFG` with `outer=X:up:down` plus origin, inner ellipse, curve, size and smoothing values.
- `/wg coords [on|off]` reports XYZ positions/deltas, 2D/3D range and active range mode, bearing/facing, ellipse settings, curve percentage, bell size and final screen offset.
- `/wg test [on|off]` remains the local target preview path.

## Current Issues
- Z is used for radial range but cannot be projected into vertical screen direction with the currently available camera data.
- Character names/identifiers for the eventual two-user ring feature are not implemented yet.
- Real ring communication remains intentionally untouched until the local bell tuning baseline is settled.

## Testing

### Last Test
- Version/state: `0.1.7-dev` on handoff commit `c02259ebf47a724ac3e395457b6cb97a62e91445`.
- Passed in WoW: first load replaced the old tuning with the promoted defaults, including `Outer Up = 60`.
- Passed in WoW: after changing a setting and restarting, the changed value persisted, confirming settings revision `2` resets only once.
- Geometry does not need further retuning unless a real issue appears.

### Next Test
- No geometry test is currently required.
- Next runtime work is the Ring Bell communication/control slice described below.
- Use the proven Vanilla 1.12.1 communication pattern from `Seraphic8x2244/pfui_tankicons`: `SendAddonMessage(prefix, payload, "RAID"/"PARTY")`, receive `CHAT_MSG_ADDON` through legacy `arg1`/`arg2`/`arg4`, and do not use modern addon-prefix registration APIs.
- No GitHub Actions/CI workflow exists in this repository.

## Planned / To-do

### 1. Ring Bell
- Runtime starts in **client mode**: the player can be rung but sees no sender control.
- `/wg ringer` switches the current session into **control/ringer mode**; provide a simple way to return to client mode.
- Client and ringer modes are mutually exclusive.
- Communication is group-scoped and must mirror the proven `pfUI_TankIcons` Vanilla 1.12.1 pattern: RAID when raided, PARTY when partied, `CHAT_MSG_ADDON` legacy event arguments, no modern prefix-registration API.
- Use a lightweight query/announce handshake so a controller knows which current group members are actively in client mode.
- In ringer mode, show the small sender bell control only while the current target has positively announced client mode.
- Clicking the sender bell starts a ring for that targeted client; clicking it again for the same active client cancels the ring.
- The recipient keeps the normal addon visually silent until rung.
- While rung, the recipient resolves the sender to the current party/raid unit token and uses the existing directional/distance geometry for bell placement when available.
- The recipient can cancel an active ring by targeting/clicking the active ringer's character; send a cancellation message so the controller can clear its active state too.
- Keep ring/cancel state explicit in the wire protocol; do not infer cancellation merely from target changes on the controller.
- No pseudo-security/authorized-ringer system; group membership plus active client-mode announcement is the intended scope.
- Keep the approved PNG as source artwork and the committed 256x64 32-bit uncompressed TGA as the WoW 1.12.1 runtime texture.

### 2. Direction and Distance Hint
- Treat ClassicAPI as an optional enhancement, not a base dependency.
- When ClassicAPI provides reliable facing and unit world positions, calculate continuous horizontal relative bearing from player to sender.
- Use XYZ distance for radial range whenever Z is available; fall back to 2D only when Z is unavailable.
- Do not fake vertical screen projection from Z without camera pitch/projection data.
- Encode approximate distance as interpolation between the inner and outer ellipse intersections along the target bearing.
- Keep the five-point distance curve available for perceptual tuning.
- Keep near/far bell size scaling tied to the same curve percentage.
- If directional data is unavailable, use a centred/non-directional fallback when real ring communication is implemented.

### 3. Recipient Screen Safe Area
- Derive placement from the recipient client's actual UI dimensions rather than assuming a resolution.
- Use configurable Origin X/Y as the apparent player position.
- Use a configurable inner ellipse as the character exclusion zone.
- Use a configurable outer travel boundary with symmetric left/right X radius and independent Up/Down Y radii.
- Define ellipse radii as percentages of screen width/height.
- Expand/contract effective ellipse intersections by bell half-size so the graphic itself respects the limits.

### 4. Blessing of Protection Gag
- Implement only after the bell foundation is working.
- The recipient's native 1.12.1 buff data cannot be relied on to identify the caster.
- Detect/confirm the sender's successful Blessing of Protection on the intended partner from the sender side and signal the recipient.
- Recipient shows a large Blessing of Protection visual and plays the locally supplied John Cena audio presentation.
- Do not trigger for failed casts, casts on another target, or another player's Blessing of Protection.
- End the presentation appropriately if the effect is removed early where reliable 1.12.1 state allows it.
- Do not commit copyrighted meme audio to the repository; support a local drop-in sound asset instead.

## Ideas / Backlog
- Direction-aware animation entry from the calculated on-screen bearing.
- Fine-tune bell size, duration, cooldown and distance curve from in-game testing rather than pre-optimizing them.

## Deferred
- Options UI.
- Minimap button.
- General-purpose configuration system.
- Libraries/frameworks.
- Public/multi-user security model.
- BoP/Cena implementation until the bell feature is working.

## Exact Next Step
Implement the first Ring Bell communication/control slice without changing the tested geometry: mirror `pfUI_TankIcons`' Vanilla 1.12.1 addon-message pattern, add session-default client mode plus `/wg ringer` control mode, discover active client-mode group members, and show the sender bell control only for a discovered client target. Wire ring/cancel state so the controller can toggle the ring and the recipient can cancel by targeting the active ringer. Keep this work on `dev` and mark it untested until verified in WoW.
