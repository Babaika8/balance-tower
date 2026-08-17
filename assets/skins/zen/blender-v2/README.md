# Zen Blender v2

This scene is authored as independent visual layers and animated objects.

- `ZEN_FAR`: continuous mountain, temple, sky, and cloud chapters.
- `ZEN_MID`: side cliffs, waterfalls, and flying kites.
- `ZEN_NEAR`: stone terrace, sakura, and hanging lantern.
- `source/`: project-bound bitmap sources used by the Blender builder.
- `zen_world.glb`: exported runtime scene consumed by Godot.

Rebuild with:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background \
  --python tools/blender/build_zen_blender_v2.py
```

The Blender timeline is 600 frames at 30 FPS. Animation is baked into the GLB;
Godot only plays it and maps the existing gameplay camera to the three depth
roots. The stacking physics and gameplay coordinates remain outside this scene.
