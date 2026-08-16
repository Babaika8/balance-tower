import bpy
import math
import os
import random
from mathutils import Vector

random.seed(8)

OUT = "/Users/marcopolo/Documents/New project 2/balance-tower/art_review/blender_zen/frames/frame_"
BLEND = "/Users/marcopolo/Documents/New project 2/balance-tower/art_review/blender_zen/zen_diorama.blend"
GLB = "/Users/marcopolo/Documents/New project 2/balance-tower/assets/skins/zen/blender/zen_world.glb"


def mat(name, color, rough=0.82, emission=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return m


def smooth(obj):
    if hasattr(obj.data, "polygons"):
        for p in obj.data.polygons:
            p.use_smooth = True


def cube(name, loc, scale, material, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    o.data.materials.append(material)
    return o


def river_plane(name, y, z_bottom, z_top, bottom_width, top_width, material):
    mesh = bpy.data.meshes.new(f"{name} mesh")
    mesh.from_pydata([
        (-bottom_width, y, z_bottom),
        (bottom_width, y, z_bottom),
        (top_width, y, z_top),
        (-top_width, y, z_top),
    ], [], [(0, 1, 2, 3)])
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def uv(name, loc, scale, material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    smooth(o)
    return o


def cylinder_between(name, a, b, radius, material, vertices=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.data.materials.append(material)
    return o


def animate_rotation(obj, values, axis=1):
    obj.rotation_mode = "XYZ"
    for frame, angle in values:
        obj.rotation_euler[axis] = angle
        obj.keyframe_insert("rotation_euler", frame=frame)


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def torii(name, loc, scale=1.0):
    root = bpy.data.objects.new(name, None)
    root.location = (0, 0, 0)
    bpy.context.collection.objects.link(root)
    for x in (-1.0, 1.0):
        post = cylinder_between(f"{name} post", (loc[0] + x * scale, loc[1], loc[2]), (loc[0] + x * scale, loc[1], loc[2] + 2.2 * scale), 0.12 * scale, red)
        post.parent = root
    for dz, width in ((2.15, 1.55), (1.82, 1.28)):
        beam = cube(f"{name} beam", (loc[0], loc[1], loc[2] + dz * scale), (width * scale, 0.13 * scale, 0.12 * scale), red, 0.04)
        beam.parent = root
    return root


def pagoda(name, loc, scale=1.0):
    root = bpy.data.objects.new(name, None)
    root.location = (0, 0, 0)
    bpy.context.collection.objects.link(root)
    for floor in range(3):
        z = loc[2] + floor * 0.82 * scale
        body = cube(f"{name} body {floor}", (loc[0], loc[1], z), (0.72 * scale, 0.48 * scale, 0.36 * scale), wood, 0.04)
        body.parent = root
        roof_part = cube(f"{name} roof {floor}", (loc[0], loc[1], z + 0.42 * scale), (1.05 * scale, 0.68 * scale, 0.10 * scale), roof, 0.05)
        roof_part.parent = root
    spire = cylinder_between(f"{name} spire", (loc[0], loc[1], loc[2] + 2.35 * scale), (loc[0], loc[1], loc[2] + 3.05 * scale), 0.055 * scale, gold)
    spire.parent = root
    return root


def kite(name, loc, phase):
    root = bpy.data.objects.new(name, None)
    root.location = loc
    bpy.context.collection.objects.link(root)
    sail = cube(f"{name} sail", loc, (0.30, 0.035, 0.42), pink_hi if phase % 2 else paper, 0.03)
    sail.rotation_euler[1] = math.radians(45)
    sail.parent = root
    sail.matrix_parent_inverse = root.matrix_world.inverted()
    tail = cylinder_between(f"{name} tail", (loc[0], loc[1], loc[2] - 0.35), (loc[0] - 0.45, loc[1], loc[2] - 1.1), 0.018, red, 8)
    tail.parent = root
    tail.matrix_parent_inverse = root.matrix_world.inverted()
    root.keyframe_insert("location", frame=1)
    root.location += Vector((1.2, 0.0, 0.55))
    root.keyframe_insert("location", frame=180)
    root.location -= Vector((1.2, 0.0, 0.55))
    root.keyframe_insert("location", frame=360)
    animate_rotation(root, [(1, -0.08), (90, 0.10), (180, -0.04), (270, 0.12), (360, -0.08)], axis=1)
    return root


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 360
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 360
scene.render.film_transparent = False
scene.world.color = (0.16, 0.30, 0.42)
scene.world.use_nodes = True
world_bg = scene.world.node_tree.nodes.get("Background")
world_bg.inputs["Color"].default_value = (0.22, 0.43, 0.52, 1)
world_bg.inputs["Strength"].default_value = 0.65

scene.view_settings.look = "AgX - Medium High Contrast"

sky = mat("sky jade", (0.35, 0.66, 0.72))
mist = mat("mist", (0.78, 0.88, 0.83))
rock = mat("wet jade rock", (0.12, 0.29, 0.25))
rock_hi = mat("moss", (0.30, 0.51, 0.31))
wood = mat("warm timber", (0.24, 0.09, 0.055))
roof = mat("temple teal", (0.025, 0.20, 0.23))
red = mat("vermilion", (0.52, 0.075, 0.055))
pink = mat("sakura", (0.94, 0.43, 0.56))
pink_hi = mat("sakura light", (1.0, 0.69, 0.74))
leaf = mat("leaf", (0.12, 0.38, 0.24))
gold = mat("lantern glow", (0.65, 0.27, 0.06), emission=(1.0, 0.42, 0.08))
paper = mat("paper", (0.95, 0.74, 0.42))
water_mat = mat("clear turquoise water", (0.025, 0.32, 0.42), rough=0.32)
foam_mat = mat("water foam", (0.68, 0.91, 0.88), rough=0.55)

# Backdrop and layered mountain silhouettes.
cube("Backdrop", (0, 2.8, 22), (8, 0.25, 26), sky, 0)
for depth, y, tone in [(0, 2.2, mist), (1, 1.3, rock_hi), (2, 0.5, rock)]:
    for i in range(6):
        x = [-5.8, -3.5, -1.15, 1.15, 3.5, 5.8][i] + depth * 0.18
        z = 4.2 + (i % 3) * 1.3 + depth * 0.35
        uv(f"Mountain {depth}-{i}", (x, y, z), (1.05, 0.36, 2.8), tone)

# Ground cliffs frame a central river corridor.
for side in (-1, 1):
    for i in range(7):
        x = side * (4.15 + random.uniform(-0.25, 0.25))
        z = i * 1.15 - 0.5
        uv(f"Cliff {side}-{i}", (x, -0.2, z), (1.45, 0.90, 0.88), rock if i % 2 else rock_hi)

# Water motion is authored as moving foam geometry so glTF preserves it.
water = river_plane("River", -0.72, -1.7, 5.2, 1.32, 0.50, water_mat)
for i in range(9):
    ripple = cube(f"River ripple {i}", (random.uniform(-0.8, 0.8), -0.81, -1.0 + i * 0.72),
                  (random.uniform(0.20, 0.52), 0.025, 0.025), foam_mat, 0.02)
    ripple.keyframe_insert("location", frame=1)
    ripple.location.z -= 1.4
    ripple.keyframe_insert("location", frame=90)
    ripple.location.z += 1.4
    ripple.keyframe_insert("location", frame=91)
    ripple.keyframe_insert("location", frame=180)

# Bridge and compact shrine.
for x in (-1.8, 1.8):
    cylinder_between("Bridge post", (x, -1.0, 2.0), (x, -1.0, 3.0), 0.10, red)
for i in range(11):
    a = -1.8 + i * 0.36
    z = 2.45 + 0.62 * (1 - (a / 1.8) ** 2)
    cube("Bridge deck", (a, -1.0, z), (0.22, 0.62, 0.09), red, 0.04)

cube("Shrine body", (-2.35, -0.05, 5.05), (1.0, 0.72, 0.85), wood)
cube("Shrine paper", (-2.35, -0.78, 5.15), (0.72, 0.04, 0.55), paper, 0.02)
roof_obj = cube("Shrine roof", (-2.35, -0.05, 6.0), (1.45, 0.98, 0.16), roof)
roof_obj.rotation_euler[1] = math.radians(4)
for x in (-2.9, -1.8):
    cylinder_between("Shrine pillar", (x, -0.72, 4.15), (x, -0.72, 5.8), 0.09, red)

# Sakura: fixed trunk, articulated branches, foliage parented to each branch.
trunk = cylinder_between("Sakura trunk", (3.15, 0, -0.3), (2.85, 0, 4.3), 0.32, wood)
for i, (base, tip, phase) in enumerate([
    ((2.92, 0, 3.0), (1.35, 0, 4.5), 0.0),
    ((2.90, 0, 3.45), (4.45, 0, 5.1), 0.8),
    ((2.87, 0, 3.9), (2.25, 0, 5.8), 1.5),
]):
    pivot = bpy.data.objects.new(f"Branch pivot {i}", None)
    pivot.location = base
    bpy.context.collection.objects.link(pivot)
    branch = cylinder_between(f"Branch {i}", base, tip, 0.15 - i * 0.015, wood)
    branch.parent = pivot
    branch.matrix_parent_inverse = pivot.matrix_world.inverted()
    for j in range(9):
        t = 0.28 + j * 0.08
        p = Vector(base).lerp(Vector(tip), t)
        p.x += random.uniform(-0.28, 0.28)
        p.z += random.uniform(-0.30, 0.30)
        blossom = uv(f"Blossom {i}-{j}", p, (0.42, 0.23, 0.32), pink_hi if j % 3 == 0 else pink)
        blossom.parent = pivot
        blossom.matrix_parent_inverse = pivot.matrix_world.inverted()
    animate_rotation(pivot, [(1, -0.018 + phase * 0.002), (60, 0.035), (125, -0.025), (190, 0.045), (240, -0.018)], axis=1)

# Hanging lantern with a real attachment pivot.
lantern_pivot = bpy.data.objects.new("Lantern attachment", None)
lantern_pivot.location = (1.55, -0.75, 4.8)
bpy.context.collection.objects.link(lantern_pivot)
cylinder_between("Lantern rope", (1.55, -0.75, 4.8), (1.55, -0.75, 4.2), 0.025, wood)
lamp = cube("Lantern", (1.55, -0.75, 3.88), (0.28, 0.22, 0.38), gold, 0.08)
lamp.parent = lantern_pivot
lamp.matrix_parent_inverse = lantern_pivot.matrix_world.inverted()
animate_rotation(lantern_pivot, [(1, -0.05), (72, 0.09), (148, -0.07), (220, 0.055), (240, -0.05)], axis=1)

# Cloud groups move at different depths and speeds.
for g in range(3):
    root = bpy.data.objects.new(f"Cloud group {g}", None)
    root.location = (-6.5 - g, 0.8 + g * 0.35, 6.2 + g * 2.0)
    bpy.context.collection.objects.link(root)
    for i in range(6):
        cloud = uv(f"Cloud {g}-{i}", (i * 0.65, 0, math.sin(i) * 0.18), (0.75, 0.28, 0.36), mist)
        cloud.parent = root
    root.keyframe_insert("location", frame=1)
    root.location.x = 7.5
    root.keyframe_insert("location", frame=360)

# Upper chapters continue the same physical world without image switches.
for band in range(1, 6):
    base_z = 7.0 + band * 5.1
    for side in (-1, 1):
        for i in range(4):
            x = side * (4.2 + random.uniform(-0.28, 0.28))
            z = base_z + i * 1.25
            uv(f"Upper cliff {band}-{side}-{i}", (x, 0.0, z), (1.45, 0.85, 1.0), rock if (band + i) % 2 else rock_hi)
    if band in (1, 3):
        pagoda(f"Pagoda {band}", ((-2.8 if band == 1 else 2.9), -0.05, base_z + 0.4), 0.75)
    if band in (2, 4):
        torii(f"Torii {band}", (0, 0.7, base_z + 0.7), 0.72)
    cloud_root = bpy.data.objects.new(f"Upper cloud bank {band}", None)
    cloud_root.location = (-6.0 - band, 1.0, base_z + 3.4)
    bpy.context.collection.objects.link(cloud_root)
    for i in range(8):
        cloud = uv(f"Upper cloud {band}-{i}", (i * 0.72, 0, math.sin(i * 1.4) * 0.22), (0.82, 0.27, 0.38), mist)
        cloud.parent = cloud_root
    cloud_root.keyframe_insert("location", frame=1)
    cloud_root.location.x = 7.0
    cloud_root.keyframe_insert("location", frame=360)

# Additional landmarks keep every camera-height chapter visually populated.
pagoda("High pagoda left", (-2.7, 0.1, 21.0), 0.72)
pagoda("Cloud pagoda right", (2.8, 0.2, 27.5), 0.62)
torii("Sky gate", (0, 0.8, 34.0), 0.82)
for z in (10.5, 18.0, 25.0, 32.0):
    for side in (-1, 1):
        cylinder_between(f"High pine trunk {z}-{side}", (side * 3.3, 0.1, z), (side * 3.15, 0.1, z + 2.2), 0.16, wood)
        for j in range(4):
            uv(f"High pine crown {z}-{side}-{j}", (side * (3.15 + j * 0.12), 0.05, z + 1.3 + j * 0.42), (0.72 - j * 0.08, 0.32, 0.46), leaf)

# A tall, geometric waterfall occupies the monastery chapter.
upper_water = cube("Upper waterfall", (2.45, -0.55, 15.2), (0.48, 0.05, 3.0), water_mat, 0.04)
for i in range(7):
    foam = uv(f"Upper waterfall foam {i}", (2.45 + random.uniform(-0.42, 0.42), -0.64, 12.25 + random.uniform(-0.15, 0.15)), (0.22, 0.05, 0.08), foam_mat)
    foam.scale.x *= 1.2
for i in range(8):
    stream = cube(f"Waterfall stream {i}", (2.15 + i * 0.085, -0.64, 17.8 - i * 0.34),
                  (0.025, 0.025, 0.38), foam_mat, 0.02)
    stream.keyframe_insert("location", frame=1)
    stream.location.z -= 2.4
    stream.keyframe_insert("location", frame=75)
    stream.location.z += 2.4
    stream.keyframe_insert("location", frame=76)
    stream.keyframe_insert("location", frame=150)

# Sky chapter accents.
kite("Kite one", (-2.8, -0.2, 27.0), 0)
kite("Kite two", (2.5, 0.4, 31.5), 1)
moon = uv("Moon", (-2.3, 1.6, 38.0), (1.05, 0.18, 1.05), paper)
for i in range(18):
    star = uv(f"Star {i}", (random.uniform(-5.5, 5.5), 1.9, random.uniform(34.0, 44.0)), (0.035, 0.02, 0.035), gold)

# Petals have authored paths and staggered timing.
for i in range(30):
    petal = uv(f"Petal {i}", (3.0 + random.uniform(-1.4, 1.4), -0.8, 5.0 + random.uniform(-1, 1.4)), (0.055, 0.018, 0.035), pink_hi)
    f0 = 1 + random.randint(0, 120)
    petal.keyframe_insert("location", frame=f0)
    petal.location += Vector((random.uniform(-3.5, -1.2), random.uniform(-0.2, 0.2), random.uniform(-4.5, -2.4)))
    petal.rotation_euler = (random.random() * 5, random.random() * 5, random.random() * 5)
    petal.keyframe_insert("location", frame=f0 + 105)
    petal.keyframe_insert("rotation_euler", frame=f0 + 105)

# Lighting and orthographic camera produce a soft illustrated diorama.
bpy.ops.object.light_add(type="AREA", location=(-3.5, -5.0, 9.5))
key = bpy.context.object
key.data.energy = 950
key.data.shape = "DISK"
key.data.size = 6.0
key.data.color = (1.0, 0.70, 0.47)
look_at(key, (0, 0, 4))
bpy.ops.object.light_add(type="AREA", location=(4.5, 1.0, 7.0))
fill = bpy.context.object
fill.data.energy = 650
fill.data.size = 5.0
fill.data.color = (0.35, 0.65, 1.0)
look_at(fill, (0, 0, 4))
bpy.ops.object.light_add(type="SUN", location=(0, -4, 22))
sun = bpy.context.object
sun.rotation_euler = (math.radians(28), math.radians(-18), math.radians(-24))
sun.data.energy = 2.2
sun.data.color = (1.0, 0.78, 0.58)

bpy.ops.object.camera_add(location=(0, -18.5, 5.1))
cam = bpy.context.object
cam.data.type = "ORTHO"
cam.data.ortho_scale = 10.4
look_at(cam, (0, 0, 4.7))
scene.camera = cam
cam.keyframe_insert("location", frame=1)
cam.location.z = 37.5
cam.keyframe_insert("location", frame=360)

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.export_scene.gltf(
    filepath=GLB,
    export_format="GLB",
    export_animations=True,
    export_animation_mode="SCENE",
    export_cameras=True,
    export_lights=True,
)
preview_frame = os.environ.get("BT_BLENDER_PREVIEW")
if preview_frame:
    scene.frame_set(int(preview_frame))
    scene.render.filepath = f"/tmp/blender_zen_{preview_frame}.png"
    bpy.ops.render.render(write_still=True)
else:
    bpy.ops.render.render(animation=True)
