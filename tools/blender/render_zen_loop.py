import bpy
import math
import os
import random
from mathutils import Vector

ROOT = "/Users/marcopolo/Documents/New project 2/balance-tower"
BASE = f"{ROOT}/assets/skins/zen/diorama/valley_base.png"
FOREGROUND = f"{ROOT}/assets/skins/zen/diorama/valley_foreground.png"
OUT = f"{ROOT}/web-next/assets/zen_blender_loop.mp4"
PREVIEW = f"{ROOT}/art_review/blender_anime3d/zen_loop_preview.png"
FRAME_DIR = f"{ROOT}/art_review/blender_anime3d/frames"

random.seed(71)


def image_material(name, image_path, alpha=False):
    image = bpy.data.images.load(image_path, check_existing=True)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    links.new(tex.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    if alpha:
        mix = nodes.new("ShaderNodeMixShader")
        transparent = nodes.new("ShaderNodeBsdfTransparent")
        links.remove(emission.outputs["Emission"].links[0])
        links.new(tex.outputs["Alpha"], mix.inputs[0])
        links.new(transparent.outputs[0], mix.inputs[1])
        links.new(emission.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], output.inputs["Surface"])
        mat.surface_render_method = "DITHERED"
    return mat


def color_material(name, color, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    node = nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, alpha)
    node.inputs["Alpha"].default_value = alpha
    node.inputs["Roughness"].default_value = 1.0
    if alpha < 1.0:
        mat.surface_render_method = "DITHERED"
    return mat


def plane(name, width, height, location, material):
    bpy.ops.mesh.primitive_plane_add(size=2, location=location, rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (width / 2, height / 2, 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def soft_mist(name, loc, scale, material, phase):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.keyframe_insert("location", frame=1)
    obj.location.x += 1.0 + phase * 0.18
    obj.location.z += 0.14
    obj.keyframe_insert("location", frame=64)
    obj.location.x -= 1.0 + phase * 0.18
    obj.location.z -= 0.14
    obj.keyframe_insert("location", frame=128)
    return obj


for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 540
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 120
scene.world.color = (0.01, 0.01, 0.01)
scene.render.image_settings.file_format = "PNG"

base = plane("painted valley", 10.0, 17.78, (0, 2.0, 0), image_material("painted valley", BASE))
foreground = plane("painted near trees", 10.0, 17.78, (0, -0.8, 0), image_material("painted near trees", FOREGROUND, alpha=True))

# Subtle depth motion comes from the camera and the full foreground, not screen warping.
foreground.location.x = -0.028
foreground.keyframe_insert("location", frame=1)
foreground.location.x = 0.040
foreground.keyframe_insert("location", frame=60)
foreground.location.x = -0.028
foreground.keyframe_insert("location", frame=120)

mist = color_material("mist", (0.73, 0.90, 0.88), 0.11)
for idx, spec in enumerate(((-2.2, 0.45, 0.8, 1.1, 0.22), (1.4, 0.7, 2.4, 1.35, 0.20), (-0.4, 0.75, 4.35, 1.8, 0.24), (2.1, 0.48, 5.7, 0.95, 0.17))):
    x, y, z, sx, sz = spec
    soft_mist(f"valley mist {idx}", (x, y, z), (sx, 0.12, sz), mist, idx)

petal = color_material("petal", (1.0, 0.40, 0.52), 0.92)
for index in range(56):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, location=(random.uniform(-4.9, 4.9), random.uniform(-0.85, -0.45), random.uniform(-7.2, 8.5)))
    obj = bpy.context.object
    obj.name = f"falling petal {index}"
    obj.scale = (0.045, 0.012, 0.026)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(petal)
    start = 1 + (index * 17) % 90
    obj.keyframe_insert("location", frame=start)
    obj.location += Vector((random.uniform(-0.85, 0.65), random.uniform(-0.08, 0.12), random.uniform(-2.2, -4.0)))
    obj.rotation_euler = (random.random() * 6.0, random.random() * 6.0, random.random() * 6.0)
    obj.keyframe_insert("location", frame=start + 56)
    obj.keyframe_insert("rotation_euler", frame=start + 56)

bpy.ops.object.camera_add(location=(0, -16.0, 0.0))
camera = bpy.context.object
camera.data.type = "ORTHO"
camera.data.ortho_scale = 17.78
camera.rotation_euler = (math.radians(90), 0, 0)
scene.camera = camera
camera.location.z = -0.08
camera.keyframe_insert("location", frame=1)
camera.location.z = 0.14
camera.keyframe_insert("location", frame=60)
camera.location.z = -0.08
camera.keyframe_insert("location", frame=120)

bpy.ops.wm.save_as_mainfile(filepath=f"{ROOT}/art_review/blender_anime3d/zen_loop.blend")
scene.frame_set(1)
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
os.makedirs(FRAME_DIR, exist_ok=True)
scene.render.filepath = f"{FRAME_DIR}/frame_"
bpy.ops.render.render(animation=True)
