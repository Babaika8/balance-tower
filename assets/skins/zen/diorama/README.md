# Zen painted diorama

Generated with the built-in ImageGen workflow on 2026-08-14.

## Direction

An original hand-painted fantasy Zen garden built as theatrical 2.5D scenery.
The art uses bold gouache-like shapes, teal and jade cliffs, coral blossom,
warm lanterns, and pale cyan atmosphere. It deliberately replaces the previous
pixel-art direction instead of extending it.

## Asset prompts

`valley_base.png` is a calm vertical valley plate with rounded mountains,
shrines, bridges, a distant river, and an open central stacking corridor.

`valley_foreground.png` is an authored transparent theatre-flat containing the
twisting cherry tree, edge vegetation, lanterns, and the integrated stone
terrace. It was generated on magenta chroma key and cleaned locally.

`sky_temple.png` continues the valley upward into a cloud shrine with side
temples, streamers, waterfalls, and kites while preserving the open center.

`valley_far.png` and `valley_mid.png` are the authored demonstration split of
the same valley composition. The active scene places far, mid, near, and
atmosphere content in separate `Parallax2D` nodes with vertical depth values
chosen for a climbing camera rather than a horizontal platformer.

The physical pedestal remains unchanged. Its old sprite is hidden only for this
visual experiment because the painted terrace now supplies the visible base.
