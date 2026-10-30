# FNAP — Ziva Implementation Instructions
## Winding sound cadence + Vent Tracker integration (lightweight changes)

### Primary goal
Make two **targeted improvements to the existing, working FNAP Godot project**, without redesigning its camera monitor or altering gameplay balance:

1. Play the supplied mechanical sound at a measured cadence **only while the player is actively clicking and holding the existing desk winding control**.
2. Replace the placeholder **VENT TRACKER** monitor tab with a usable page based on the supplied ventilation map, including honest live UI status where already available and a clean future hook for actual animatronic vent positions.

**Use these exact resource paths (case, spaces, and extension matter):**

- Winding sound: `res://windup2.wav` (in the FNAP project root)
- Vent map: `res://assets/maps/Retro Ventilation Network Map.png` (in the **same maps folder** as the existing CCTV camera map)

First verify both paths exist in the running Godot project. Do **not** rename, move, regenerate, or modify these assets. If a path is missing, report it instead of silently substituting another image/sound.

### Existing systems to preserve

- Existing working `camera_system.gd` and monitor flip / camera tab / VENT TRACKER tab architecture
- All seven CCTV image feeds and their exact camera mappings, image fitting, ambient static, camera-switch burst, and REC UI
- `office.gd` office camera panning, left/right doors, hallway lights, and vent gate
- `A` left-door, `D` right-door, `W` vent-gate keybindings and their existing lockouts
- Existing desk winding mechanic and its actual meter / progress / depletion logic
- `FNAP_Beta_Code.gd` AI simulation, power ownership/usage, clock and night progression
- RED → BLACK power-out sequence, retry, game over, 6 AM priority, and audio already present

Do not create a second power system, duplicate the winding mechanic, change AI difficulty, or redesign production scenes unnecessarily. Favor minimal, clearly scoped changes. Back up any production files touched.

---

## A. Mechanical winding sound

**Asset:** `res://windup2.wav` — a short, single-shot mechanical winding sound (roughly 0.28 seconds long).

### Behavior

- Trigger the sound **only when the existing desk winding control is actively being held with the mouse AND the game has accepted that input as actual winding**.
- Begin with a single sound at the start of a valid press-and-hold, then play it again at a **0.40-second interval** for as long as the winding action remains valid. The sample should not be looped at its own file length: 0.40 seconds is the intended start-to-start cadence.
- Don't overlap multiple voices/samples. Use a single `AudioStreamPlayer` or equivalent one-shot player. Avoid rapid-fire repetition or a pitch-shifted mechanical buzz.
- Releasing the mouse, moving into a state that disables winding, or ending the shift **immediately cancels further repetitions**. Make sure no stale timer/event starts another click later.
- A quick single click should play at most one winding sound if it actually winds. Hovering over the desk object, simply opening CCTV, or tapping `W` for the vent gate should never start this audio.
- Repeated presses should restart the 0.40-second cadence cleanly; no multiple active timers or sound stacking after retries.
- Keep the sound present but not overpowering. Expose its volume in a convenient editor setting; select a sensible initial volume after listening in-game, rather than changing the WAV itself.
- The winding progress / meter should behave **exactly as it does now**. This is an audio enhancement, not a balance/mechanics rewrite.
- Ensure audio stops or becomes inactive appropriately during CCTV modes if the existing winding control isn't allowed there, when power is exhausted, on game over, and at 6 AM. Respect the *actual current game rules*.

### Suggested implementation

Inspect how the desk winding button actually detects pressed/held state. Tie audio scheduling to **the authoritative existing winding-active state**, rather than creating a parallel fake winding mode. Delta-time scheduling or a safely managed Godot Timer are both acceptable; make sure long/short frames don't produce stacked sound triggers. Keep the WAV one-shot (no `loop`).

---

## B. Functional-looking Vent Tracker page

**Asset:** `res://assets/maps/Retro Ventilation Network Map.png`

### Integrate into the existing monitor

- Use the already-existing **VENT TRACKER** tab/button in the current CCTV monitor. Clicking it should reveal a distinct tracker page; clicking the CCTV tab returns to the existing camera interface.
- Display the exact supplied vent map prominently in the tracker panel. This source image is approximately square; **preserve aspect ratio and show the entire map**, including route edges, labels, and endpoints. Prefer centered `KEEP_ASPECT_CENTERED`/contain-style behavior with background framing or intentional margins. **Do not stretch or full-bleed crop away the vent branches** just to fill a widescreen view.
- Make the tracker readable at the current normal game window size. Don't let it cover the camera/vent tabs, block navigation, or capture mouse clicks unintentionally.
- Keep the monitor's existing flip behavior, state/power constraints, and input locks unchanged. Merely switching to the tracker must not add a new power cost unless the current design already does.
- Do not alter the existing CCTV source image map or the CAM 1–7 feeds.

### What should work *now* (before animatronic visuals are added)

1. **Navigation:** The VENT TRACKER tab shows the map, and switching back to CCTV restores the previous selected camera/feed and all its existing effects. Repeated switching works, including rapid transitions.
2. **Live vent gate status if feasible from existing data:** Display a restrained `GATE OPEN` / `GATE CLOSED` indicator based on the **real office vent gate state**. Use the existing authoritative property/signal/function rather than duplicating control state. If the gate state is not cleanly available, leave out the indicator and report why instead of making it up.
3. **Display/UI polish:** Optionally add a faint, slow scanning line or subtle radar-style pulse to make the screen feel alive (not a loud or obstructive animation). It must **not** imply that movement was detected when it wasn't.
4. **No fabricated contacts:** Until there are real vent position events, do **not** show random animatronic dots or claim `MOTION DETECTED`. A neutral `NO CONTACT DATA` / `TRACKER STANDBY` label is fine. Do not invent a vent AI or alter the current invisible AI simulation just for this UI.
5. **Future integration hook:** Create a small, documented interface that can accept actual vent-contact updates later (e.g. contact ID plus a normalized map coordinate or an explicitly declared vent node, with a clear/remove method). Show markers *only when real game data calls the interface*. Keep future endpoints separated from present-day UI effects. Do not claim map coordinates or node connectivity were established if they weren't.
6. **Optional developer-only proof:** If useful, provide a manual test helper or debug mode to place/remove one sample marker and verify the overlay follows the map when resized. This must be disabled in normal player-facing gameplay. No fake player-facing detections.

### Aesthetic intent

This should resemble a low-budget, retro school ventilation monitor: dark, legible, minimal UI. It does **not** need photorealistic live vent camera feeds. Avoid hiding the map with aggressive static, very bright effects, or a giant REC label. The existing CCTV static burst should remain tied to the CCTV switching logic; opening the tracker should not accidentally flash every CCTV image.

---

## C. Keep verification SHORT, but check for bugs

**No exhaustive resolution suites, 20+ screenshots, long scripted regression marathons, or six-minute endurance runs for this task.** We want a functional, stable update without unnecessary testing overhead.

Do these focused checks:

1. Confirm both exact files import, with no missing-resource or syntax errors.
2. In one normal game window, hold the desk winding control for several seconds: confirm the sound starts once, repeats at roughly 0.40 s, does not overlap, and stops promptly when released. Try a very quick press and a second hold.
3. Open the monitor, select VENT TRACKER, confirm the **full vent image is visible and correctly proportioned**, and switch back to a known functioning CCTV feed. Check one or two different cameras and the existing CCTV static/REC.
4. If gate status was implemented, toggle the vent with `W` under the usual allowed conditions and verify status follows reality. Do not override current input lockouts.
5. Quick sanity check for monitor flip, power-out/winding lockout, and retry to ensure neither sound nor tracker gets stuck.
6. Check Godot's parser/runtime logs for errors and report any relevant warnings.

If you encounter a genuine failure, investigate that specific problem rather than expanding testing indiscriminately.

### Final report requested

- List modified/added files and backup location.
- Confirm both exact resource paths loaded.
- State how the 0.40-second audio cadence is implemented and what volume was chosen.
- Explain how the vent map is fitted and which interactive functions work today.
- Explicitly distinguish **real working tracker status** from **future-only contact hooks**.
- Summarize the brief test results and any remaining limitations.

**Priority: a reliable, polished addition that preserves the entire working FNAP office.**
