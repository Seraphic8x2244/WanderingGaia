# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.0-dev`
- Goal: Build WanderingGaia as a small personal WoW 1.12.1 addon with a directional "ring bell" aid first, followed by the Blessing of Protection gag as a separate feature slice.

## Recent Commits
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
- No in-game behaviour has been implemented or user-tested yet.

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
  - intended to mirror in-game for the opposite swing direction.

## Current Issues
- Character names/identifiers for the two intended users have not yet been added to implementation.
- The committed bell PNG is source artwork; a WoW 1.12.1 runtime texture format such as 32-bit TGA still needs to be produced before the addon can load it in game.

## Testing

### Last Test
- Version/commit: None
- Passed: None
- Failed: None
- Not tested: All runtime behaviour.

### Next Test
- First runtime smoke test after the initial bell slice is implemented:
  - addon loads on WoW 1.12.1 without Lua errors;
  - bell control appears only when the intended partner character is targeted;
  - clicking the bell sends one ring event;
  - recipient client receives and displays the bell effect;
  - native fallback remains usable when directional extension data is unavailable.

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
Convert the approved 256x64 bell sprite to a WoW 1.12.1-compatible 32-bit TGA, then implement the first Bell slice on `dev`: intended-partner target detection, sender-side clickable bell control, 1.12.1-compatible ring transport, and recipient-side centred bell presentation with a clean fallback path. Keep ClassicAPI directional/distance placement as the next enhancement after the basic ring path is confirmed working in game.
