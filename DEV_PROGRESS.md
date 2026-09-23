# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.0-dev`
- Goal: Build WanderingGaia as a small personal WoW 1.12.1 addon with a directional "ring bell" aid first, followed by the Blessing of Protection gag as a separate feature slice.

## Recent Commits
- `0b793578eccb613a45fdf3350ab40e16efdf43e6` - Add local directional bell preview.
- `b8c3f870cda6297eb70f904f65fffaabb651a196` - Add target preview locale strings.
- `b16f92218b73f4f71fa7677dc9722297ccf6f0b3` - Plan local directional bell preview.
- `00f5f001bee5b205496958a81cb26f12de1f9725` - Add 256x64 four-frame bell swing source artwork.
- `4167d3afc2666ace134a100920505b30de6a5e12` - Document WanderingGaia initial development scope.
- `1922a93a8787c5649f00938483e5e6cbbd860324` - Add artwork directory scaffold.
- `0c178ae71615f061067126889204cccda48be070` - Add enUS locale scaffold.
- `6c7154c794ceb635819f338d3b5437b98026cabf` - Add WanderingGaia main Lua file.
- `f46ecee9cc7bcb58992ba46efbf173ac49f8992f` - Add WanderingGaia dev TOC.
- `1c27d9e8abdb348c1b085627d2ae23f066dd2b5a` - Add development guide.
- `6b205fda44adca61bc1dd4bd6b6ea2e3ed95d612` - Initialize repository README on `main` before creating `dev`.

## Completed / Verified
- Repository initialized.
- `dev` branch created.
- VanillaTemplate development structure copied and renamed for WanderingGaia.
- Development contract copied from VanillaTemplate without project-specific changes.
- Initial feature scope agreed and recorded below.
- Four-frame bell swing artwork approved by the user and committed as `artwork/WanderingGaia_BellSwing_256x64.png`.
- No runtime behaviour has been user-tested yet.

## Implemented / Awaiting Test
- Development scaffold:
  - `WanderingGaia.toc`
  - `WanderingGaia.lua`
  - `locales/enUS.lua`
  - `artwork/`
  - `DEV_GUIDE.md`
  - `DEV_PROGRESS.md`
- Bell source sprite:
  - 256x64 sheet;
  - four 64x64 frames;
  - progression is centre -> slight left -> further left -> full left;
  - mirrored in-game for the opposite swing direction.
- Local target-preview harness:
  - `/wgtest`, `/wgtest on`, `/wgtest off`;
  - uses ClassicAPI `GetPlayerFacing()` and the ClassicAPI four-return `UnitPosition()` shape;
  - treats the local player as the recipient and current target as the remote player;
  - calculates continuous 2D relative bearing and distance;
  - applies the agreed left/right 20% and bottom 30% safe-area exclusions;
  - uses the agreed non-linear distance curve and near-distance deadzone;
  - animates the four-frame bell by mirroring the left-swing frames for the opposite half-cycle.

## Current Issues
- Character names/identifiers for the two intended users have not yet been added to implementation.
- The local target-preview path is implemented but untested in game.
- The committed bell PNG is source artwork; the 256x64 32-bit uncompressed TGA runtime texture has been prepared locally but still needs to be committed to `artwork/` before the preview can render in WoW 1.12.1.

## Testing

### Last Test
- Version/commit: None
- Passed: None
- Failed: None
- Not tested: All runtime behaviour.

### Next Test
- Local target-preview smoke test after the TGA is committed:
  - addon loads on WoW 1.12.1 without Lua errors;
  - with ClassicAPI loaded, `/wgtest` enables the preview;
  - no target hides the bell;
  - selecting a visible target places the bell in the correct relative direction;
  - turning in place moves the bell around the safe playfield appropriately;
  - moving toward/away from the target changes radius according to the distance curve;
  - the four-frame swing animates and mirrors correctly;
  - `/wgtest off` hides the preview.

## Planned / To-do

### 1. Ring Bell
- Keep the recipient's addon normally silent and visually absent.
- On the sender's client, show a small bell control when targeting the intended partner character.
- Clicking the bell sends a lightweight addon event to the recipient through a 1.12.1-compatible group channel.
- The recipient displays a short bell visual and plays the bell sound locally.
- No pseudo-security/authorized-ringer system; this is a personal addon, not an access-control mechanism.
- Convert the approved bell source sprite to an in-game-compatible runtime texture before wiring the animation.

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
- Use the centre of that safe playfield as the positional origin rather than the literal physical screen centre.
- Cast the directional ray from that origin and place the bell by percentage of usable distance to the intersected safe-area boundary.
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
Commit the prepared 256x64 32-bit uncompressed TGA runtime texture to `artwork/`, then user-test the existing `/wgtest` local target-preview harness in WoW 1.12.1 with ClassicAPI. Do not wire real ring communication until the local direction, distance, safe-area placement and animation are confirmed in game.
