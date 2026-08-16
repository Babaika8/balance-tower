import bpy
import math
import random
from mathutils import Vector

random.seed(8)

OUT = "/Users/marcopolo/Documents/New project 2/balance-tower/art_review/blender_zen/frames/frame_"
BLEND = "/Users/marcopolo/Documents/New project 2/balance-tower/art_review/blender_zen/zen_diorama.blend"


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
scene.frame_end = 240
scene.render.film_transparent = False
scene.world.color = (0.16, 0.30, 0.42)

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

# Backdrop and layered mountain silhouettes.
cube("Backdrop", (0, 2.8, 7), (8, 0.25, 10), sky, 0)
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

# River uses a real animated material rather than screen-space distortion.
water = cube("River", (0, -0.72, 1.8), (1.32, 0.06, 3.5), mat("water", (0.03, 0.47, 0.58), rough=0.24), 0.03)
wm = water.data.materials[0]
nodes = wm.node_tree.nodes
links = wm.node_tree.links
tex = nodes.new("ShaderNodeTexNoise")
tex.inputs["Scale"].default_value = 5.5
tex.inputs["Detail"].default_value = 3.0
mapping = nodes.new("ShaderNodeMapping")
coord = nodes.new("ShaderNodeTexCoord")
ramp = nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color = (0.01, 0.19, 0.25, 1)
ramp.color_ramp.elements[1].color = (0.18, 0.88, 0.91, 1)
links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
links.new(ramp.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
mapping.inputs["Location"].default_value[1] = 0
mapping.inputs["Location"].keyframe_insert("default_value", index=1, frame=1)
mapping.inputs["Location"].default_value[1] = 3.5
mapping.inputs["Location"].keyframe_insert("default_value", index=1, frame=240)

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
    root.keyframe_insert("location", frame=240)

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

bpy.ops.object.camera_add(location=(0, -18.5, 5.1))
cam = bpy.context.object
cam.data.type = "ORTHO"
cam.data.ortho_scale = 10.4
look_at(cam, (0, 0, 4.7))
scene.camera = cam
cam.keyframe_insert("location", frame=1)
cam.location.z = 7.1
cam.keyframe_insert("location", frame=240)

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.render.render(animation=True)
