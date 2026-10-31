FNAP monitor flip — transparent 720p frames (30 FPS)
===================================================

WHAT'S INCLUDED
- frames/flip_000.png through flip_013.png (14 RGBA frames, 1280x720)
- MonitorFlip.tres: Godot 4 SpriteFrames with two animations:
   flip_up   (plays the monitor covering the screen)
   flip_down (plays the same frames in reverse)

TO INSTALL
1. Extract this zip, then copy its 'monitor_flip' folder into
   YOUR_GODOT_PROJECT/assets/ so the resource path becomes:
   res://assets/monitor_flip/MonitorFlip.tres
2. In Godot, add an AnimatedSprite2D to a CanvasLayer that displays above
   the 3D office. In the AnimatedSprite2D Inspector, load the
   MonitorFlip.tres file into the Sprite Frames property.
3. Keep AnimatedSprite2D centered on screen and adjust its scale so
   the 1280x720 animation fills your game's visible area. Turn OFF
   Autoplay/Playing, and make sure animation Loop is off.
4. In your camera UI script, play("flip_up") when opening the monitor
   and play("flip_down") when closing. Show the camera feed AFTER
   the flip_up animation finishes; restore the office as flip_down
   finishes. Do not put the sprite behind the camera UI.

NOTE: The ending frame is essentially opaque black so you should switch
from the animation to the camera footage as it finishes (and vice versa
before flip_down starts). The PNGs do NOT contain footage or the map.

For now the animation alone will not automatically connect to camera
controls. No original project scripts were changed.

Based on the supplied video: 'Fnaf Jrs Camera green screen - Dave Miller'.
If you distribute FNAP, check that you have permission to reuse the source.
