import bpy
import math
import os

ROOT = "/Users/marcopolo/Documents/New project 2/balance-tower"
ASSET = f"{ROOT}/assets/skins/zen/authored-v1"
OUT = f"{ROOT}/art_review/blender_authored_v1"


def alpha_material(name, filename):
    image = bpy.data.images.load(filename, check_existing=True)
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    emission = nodes.new("ShaderNodeEmission")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    links.new(texture.outputs["Color"], emission.inputs["Color"])
    links.new(texture.outputs["Alpha"], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    material.surface_render_method = "DITHERED"
    return material


def card(name, image_path, width, position, parent=None):
    image = bpy.data.images.load(image_path, check_existing=True)
    height = width * image.size[1] / image.size[0]
    bpy.ops.mesh.primitive_plane_add(size=2, location=position, rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (width / 2, height / 2, 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(alpha_material(name, image_path))
    if parent:
        obj.parent = parent
    return obj


def swing(name, object_card, pivot, amplitude, phase=0):
    anchor = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(anchor)
    anchor.location = pivot
    bpy.context.view_layer.update()
    world_matrix = object_card.matrix_world.copy()
    object_card.parent = anchor
    object_card.matrix_parent_inverse = anchor.matrix_world.inverted()
    object_card.matrix_world = world_matrix
    for frame, angle in ((1, 0.0), (34 + phase, amplitude), (72 + phase, -amplitude * 0.64), (104 + phase, amplitude * 0.35), (120, 0.0)):
        anchor.rotation_euler[1] = angle
        anchor.keyframe_insert("rotation_euler", index=1, frame=frame)
    return anchor


for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 540
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 120
scene.world.color = (0.01, 0.01, 0.01)

# The static base deliberately contains no moving lantern, blossom branch or waterfall.
base = card("base_gorge", f"{ASSET}/source/base_gorge.png", 10.0, (0, 2.0, 0))

# Independent object cards. Their pivots model real attachment points in the world.
branch = card("sakura_branch", f"{ASSET}/objects/sakura_branch.png", 6.1, (-2.05, 0.65, 5.7))
swing("sakura_root", branch, (-5.05, 0.65, 4.15), math.radians(0.55), 0)

lantern = card("hanging_lantern", f"{ASSET}/objects/lantern.png", 1.22, (3.70, 0.38, 2.35))
swing("lantern_hook", lantern, (3.70, 0.38, 4.10), math.radians(1.9), 9)

waterfall = card("waterfall", f"{ASSET}/objects/waterfall.png", 1.02, (2.15, 1.22, -0.05))
waterfall.name = "waterfall_static_source"

# Camera is locked to the same human-eye composition as the mobile game.
bpy.ops.object.camera_add(location=(0, -16.0, 0.0))
camera = bpy.context.object
camera.data.type = "ORTHO"
camera.data.ortho_scale = 17.78
camera.rotation_euler = (math.radians(90), 0, 0)
scene.camera = camera

bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/zen_authored_v1.blend")
scene.frame_set(int(os.environ.get("BT_FRAME", "1")))
scene.render.filepath = f"{OUT}/preview_{scene.frame_current}.png"
bpy.ops.render.render(write_still=True)
