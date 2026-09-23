# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.2-dev`
- Implementation head ready for in-game test: `fb11dc26a599fa8cb2e075bcec22b43ee19673e3`
- Goal: Build WanderingGaia as a small personal WoW 1.12.1 addon with a directional "ring bell" aid first, followed by the Blessing of Protection gag as a separate feature slice.

## Recent Commits
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
- Bell swing animation timing remains `0.07` seconds per sprite step and was deliberately not made configurable.

## Implemented / Awaiting Test
- `0.1.2-dev` tuning workflow:
  - `/wg test [on|off]` replaces the old standalone `/wgtest` command.
  - `/wg config` opens a draggable tuning panel without implicitly enabling the preview.
  - opening config shows translucent grey left/right/up/down exclusion overlays plus a centred near-range marker.
  - left/right/up/down screen deadzones are editable percentages.
  - five-point distance-to-outer-limit curve is editable; point 1 is the centre deadzone with radius fixed at 0%.
  - curve preview visualises the currently applied points.
  - near and far bell sizes are independently configurable; size interpolates using the same distance curve percentage.
  - optional movement smoothing is configurable and defaults to 0%, preserving raw 0.1.1 behaviour.
  - optional `Use Z for range` switches the distance curve from horizontal XY range to XYZ range when Z is available.
  - Z is deliberately not projected onto screen direction because the documented ClassicAPI addon surface exposes world Z and player yaw but not the camera pitch/projection state needed for a correct screen-plane transform.
  - settings persist in `WanderingGaiaDB`.
  - Copy settings produces a selectable one-line `WGCFG` string for pasting back into development chat.
- `/wg coords [on|off]` toggles live diagnostics showing player/target XYZ, deltas, 2D/3D range, selected range mode, facing/bearing/relative angle, curve percentage, bell size and screen offset.
- Existing direction calculation, direct UI-centre anchoring and animation interval are preserved.

## Current Issues
- The entire `0.1.2-dev` config/diagnostic slice is statically checked but not yet user-tested in game.
- Z can be used honestly for 3D range, but not for vertical screen-direction projection with the currently documented ClassicAPI Lua data.
- Character names/identifiers for the eventual two-user ring feature are not implemented yet.
- Real ring communication remains intentionally untouched until the local bell tuning baseline is settled.

## Testing

### Last Test
- Version/state: `0.1.1-dev`, after the direct `UIParent CENTER` anchor correction.
- Passed: user reports centre/directional behaviour works about as well as expected from the DLL position data.
- Passed: directional movement remains convincing in practical target/rotation testing.
- Superseded issue: the earlier 0.1.0 off-centre orbit is fixed.

### Next Test
- Update through TocPilot to `0.1.2-dev` / implementation head `fb11dc26a599fa8cb2e075bcec22b43ee19673e3`.
- Confirm `/wg test on` still gives the same direction/centre feel as the verified 0.1.1 baseline.
- Run `/wg config`:
  - confirm the panel opens and the grey left/right/up/down overlays match the configured percentages;
  - Apply an obvious edge-deadzone change and verify the overlay and bell travel limit move together;
  - alter one curve point and verify the bell radius changes accordingly, then restore/tune it;
  - try different near/far sizes and confirm bell size changes with range;
  - leave smoothing at 0 first, then optionally try a moderate value to judge whether it improves DLL jitter without making movement laggy;
  - toggle Use Z for range somewhere with a meaningful height difference and compare the radial-distance feel; screen direction should remain based on horizontal bearing.
- Run `/wg coords` and verify the live values look plausible while moving/turning and targeting.
- Use Copy settings and paste the resulting `WGCFG` line back into chat so the tuned values can become the default install settings.

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
- When ClassicAPI provides reliable facing and unit world positions, calculate the sender's exact relative 2D bearing from the recipient and ignore Z.
- Use continuous bearing rather than snapping to coarse left/right/front/back sectors.
- Include a near-distance deadzone so effectively overlapping positions do not produce unstable direction.
- If directional data is unavailable, use a centred non-directional bell fallback.
- Encode approximate distance as how far the bell appears from the safe-area centre toward the screen edge in the sender's direction.
- Tune the distance curve perceptually rather than using a strict linear yards-to-screen mapping.
- Current target behaviour:
  - approximately 10 yards -> about 20% toward the available edge;
  - approximately 90 yards -> about 90% toward the available edge;
  - very large distances clamp before the visual boundary.

### 3. Recipient Screen Safe Area
- Derive placement from the recipient client's actual UI dimensions rather than assuming a resolution.
- Reserve likely UI-heavy regions:
  - left 20% excluded;
  - right 20% excluded;
  - bottom 30% excluded;
  - top remains available apart from icon padding.
- Use `UIParent`'s actual `CENTER` anchor as the positional origin because direction is relative to the player character.
- Express bell travel only as offsets from that centre anchor; do not reconstruct the centre from `BOTTOMLEFT` coordinates.
- Cast the directional ray from the centre anchor and place the bell by percentage of usable distance to the intersected safe-area boundary.
- Keep the bell frame itself fully inside the usable region.

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
Update through TocPilot to `0.1.2-dev` / `fb11dc26a599fa8cb2e075bcec22b43ee19673e3`. First confirm `/wg test on` preserves the verified 0.1.1 direction/centre behaviour. Then open `/wg config`, visually verify the grey deadzone overlays, tune edge exclusions / distance curve / near-far size / optional smoothing / optional Z range, check `/wg coords`, and paste the Copy settings `WGCFG` line back into chat. Use that runtime result to set the good baseline defaults before implementing real ring communication.
