# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.4-dev`
- Implementation head ready for in-game test: `49446d640b9bf658e98e08789919e3d2c166774f`
- Current tuning model: configurable player-origin + inner character-exclusion ellipse + outer travel ellipse + distance curve + range-based bell size.
- Goal: Build WanderingGaia as a small personal WoW 1.12.1 addon with a directional "ring bell" aid first, followed by the Blessing of Protection gag as a separate feature slice.

## Recent Commits
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

## Implemented / Awaiting Test
- `0.1.4-dev` ellipse tuning model:
  - `Origin X (%)` / `Origin Y (%)` move the visual player-origin relative to true UI centre.
  - `Inner X/Y` are ellipse radii as percentages of screen width/height and define the character exclusion zone.
  - `Outer X/Y` are ellipse radii as percentages of screen width/height and define maximum normal bell travel.
  - the bell starts on the inner ellipse at the minimum-range end of the curve and interpolates toward the outer ellipse according to the existing five-point distance curve.
  - the effective inner boundary expands by half the current bell size and the effective outer boundary contracts by half the bell size, so the bell graphic itself respects the configured ellipses rather than only its centre point.
  - a final physical-screen clamp prevents deliberately extreme origin/ellipse settings from losing the bell off-screen.
  - opening `/wg config` shows a translucent filled inner ellipse, a dotted outer ellipse and an origin cross/label.
  - range calculation always uses XYZ distance when both Z values are available; there is no longer a user-facing Z toggle. If Z is unavailable, the runtime falls back to 2D and `/wg coords` reports that fallback.
  - horizontal screen direction still uses the existing relative 2D bearing because camera pitch/projection data is not available.
  - range-based near/far bell sizing remains enabled and uses the same curve percentage.
  - smoothing remains configurable and defaults to 0%.
  - animation timing remains fixed at `0.07` seconds per sprite step.
  - settings persist in `WanderingGaiaDB`.
  - Copy settings exports `WGCFG` with origin, inner/outer ellipse radii, curve, size and smoothing values.
- `/wg coords [on|off]` reports XYZ positions/deltas, 2D/3D range and active range mode, bearing/facing, ellipse settings, curve percentage, bell size and final screen offset.
- `/wg test [on|off]` remains the local target preview path.

## Current Issues
- The ellipse geometry/config overlay is statically checked but not yet user-tested in WoW.
- `0.1.3-dev` movable-origin testing was superseded by the requested ellipse model before a focused result was recorded.
- Z is used for radial range but cannot be projected into vertical screen direction with the currently available camera data.
- Character names/identifiers for the eventual two-user ring feature are not implemented yet.
- Real ring communication remains intentionally untouched until the local bell tuning baseline is settled.

## Testing

### Last Test
- Version/state: `0.1.2-dev`.
- Passed: user reports the tuning controls are good overall in game.
- Directional movement remains acceptable.
- User preference established from tuning: XYZ/Z-inclusive range feels better, and range-based bell sizing feels natural.
- Geometry change requested after this test: replace rectangular limits with inner/outer ellipses around the movable player-origin.

### Next Test
- Update through TocPilot to `0.1.4-dev` / implementation head `49446d640b9bf658e98e08789919e3d2c166774f`.
- Open `/wg config` and first tune Origin Y so the origin cross visually matches the character.
- Tune `Inner X/Y` until the filled grey inner ellipse covers the character area the bell should never enter.
- Tune `Outer X/Y` until the dotted outer ellipse describes the desired maximum travel shape.
- Run `/wg test on` and rotate around targets at several ranges:
  - confirm the bell never enters the inner character ellipse;
  - confirm it moves naturally toward but does not normally pass the outer ellipse;
  - confirm range-based size still feels natural;
  - confirm height differences affect radial range without changing the horizontal bearing direction;
  - confirm the existing distance curve remains useful, or report if a near-linear curve is sufficient.
- Run `/wg coords` while testing and confirm range mode normally reports `3D`.
- Use Copy settings and paste the resulting `WGCFG` line back into chat once the geometry feels right.

## Planned / To-do

### 1. Ring Bell
- Keep the recipient's addon normally silent and visually absent.
- On the sender's client, show a small bell control when targeting the intended partner character.
- Clicking the bell sends a lightweight addon event to the recipient through a 1.12.1-compatible group channel.
- The recipient displays a short bell visual and plays the bell sound locally.
- No pseudo-security/authorized-ringer system; this is a personal addon, not an access-control mechanism.
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
- Use a configurable outer ellipse as the normal maximum travel boundary.
- Define ellipse X/Y values as radii in percentages of screen width/height.
- Expand/contract effective ellipse intersections by bell half-size so the graphic itself respects the limits.
- Retain a physical screen-edge clamp as a final safety guard only.

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
Update through TocPilot to `0.1.4-dev` / `49446d640b9bf658e98e08789919e3d2c166774f`. In `/wg config`, tune Origin Y first, then Inner X/Y around the character and Outer X/Y for maximum travel. Test `/wg test on` across bearings, ranges and height differences; confirm the bell stays outside the inner ellipse, respects the outer ellipse, uses 3D range and retains natural range-based sizing. Then paste the Copy settings `WGCFG` line back into chat so the tuned values can become the install defaults.
