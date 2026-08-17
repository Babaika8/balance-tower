import math
import os
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/skins/zen/blender-v2/source"
EXPORT = ROOT / "assets/skins/zen/blender-v2/zen_world.glb"
REVIEW = ROOT / "art_review/blender_v2"

FRAME_START = 1
FRAME_END = 600
FPS = 30
VIEW_W = 5.85
VIEW_H = 10.40
VIEW_CENTER_Z = 5.10
SECTION_STEP_Z = 9.70


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def material_for(name, image_path, alpha=True):
    image = bpy.data.images.load(str(image_path), check_existing=True)
    image.colorspace_settings.name = "sRGB"
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    shader.inputs["Roughness"].default_value = 0.92
    shader.inputs["Specular IOR Level"].default_value = 0.12
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    if "Emission Color" in shader.inputs:
        links.new(texture.outputs["Color"], shader.inputs["Emission Color"])
        shader.inputs["Emission Strength"].default_value = 0.78
    if alpha:
        links.new(texture.outputs["Alpha"], shader.inputs["Alpha"])
        if hasattr(material, "surface_render_method"):
            material.surface_render_method = "DITHERED"
    links.new(shader.outputs[0], output.inputs["Surface"])
    return material, image


def make_grid_card(
    name,
    image_path,
    width,
    center,
    parent,
    cols=1,
    rows=1,
    alpha=True,
    uv_rect=(0.0, 0.0, 1.0, 1.0),
):
    material, image = material_for(f"MAT_{name}", image_path, alpha)
    u0, v0, u1, v1 = uv_rect
    crop_width = image.size[0] * (u1 - u0)
    crop_height = image.size[1] * (v1 - v0)
    height = width * crop_height / crop_width
    vertices = []
    uvs = []
    faces = []
    for row in range(rows + 1):
        local_v = row / rows
        v = v0 + local_v * (v1 - v0)
        z = (local_v - 0.5) * height
        for col in range(cols + 1):
            local_u = col / cols
            u = u0 + local_u * (u1 - u0)
            x = (local_u - 0.5) * width
            vertices.append((x, 0.0, z))
            uvs.append((u, v))
    stride = cols + 1
    for row in range(rows):
        for col in range(cols):
            a = row * stride + col
            faces.append((a, a + 1, a + stride + 1, a + stride))

    mesh = bpy.data.meshes.new(f"MESH_{name}")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            uv_layer.data[loop_index].uv = uvs[vertex_index]

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.location = center
    obj.parent = parent
    return obj, width, height


def add_shape(obj, name, deform):
    if obj.data.shape_keys is None:
        obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name=name)
    for index, point in enumerate(key.data):
        base = obj.data.vertices[index].co
        point.co = deform(index, base.copy())
    return key


def key_value(block, frames):
    for frame, value in frames:
        block.value = value
        block.keyframe_insert("value", frame=frame)


def set_bezier(action):
    if action is None or not hasattr(action, "fcurves"):
        return
    for curve in action.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = "BEZIER"


def animate_sakura(parent):
    tree, width, height = make_grid_card(
        "SakuraRig",
        SOURCE / "sakura.png",
        6.7,
        (-2.65, -3.1, 6.15),
        parent,
        cols=10,
        rows=18,
    )
    cols = 10
    rows = 18

    def breeze(sign, strength):
        def deform(index, point):
            row = index // (cols + 1)
            col = index % (cols + 1)
            u = col / cols
            v = row / rows
            anchored = max(0.0, min(1.0, (u * 0.80 + v * 0.65) - 0.28))
            wave = math.sin(v * math.pi * 1.45 + u * 1.8)
            point.x += sign * strength * anchored * (0.70 + 0.30 * wave)
            point.z += strength * 0.12 * anchored * math.sin(u * math.pi * 2.0)
            return point

        return deform

    left = add_shape(tree, "BreezeLeft", breeze(-1.0, 0.28))
    right = add_shape(tree, "BreezeRight", breeze(1.0, 0.34))
    gust = add_shape(tree, "Gust", breeze(1.0, 0.58))
    key_value(left, [(1, 0), (72, 0.55), (128, 0), (250, 0.35), (318, 0), (470, 0.25), (600, 0)])
    key_value(right, [(1, 0), (150, 0), (210, 0.58), (278, 0), (360, 0.42), (430, 0), (600, 0)])
    key_value(gust, [(1, 0), (325, 0), (354, 0.88), (386, 0.16), (420, 0), (600, 0)])
    set_bezier(tree.data.shape_keys.animation_data.action)


def animate_lantern(parent):
    bracket, _, _ = make_grid_card(
        "LanternBracket",
        SOURCE / "lantern.png",
        2.15,
        (2.05, -3.0, 8.55),
        parent,
        cols=1,
        rows=1,
        uv_rect=(0.31, 0.63, 1.0, 1.0),
    )
    bracket.scale = (1.0, 1.0, 1.0)
    hook = bpy.data.objects.new("LanternHook", None)
    bpy.context.collection.objects.link(hook)
    hook.parent = parent
    hook.location = (1.45, -3.08, 8.08)
    lantern, _, _ = make_grid_card(
        "LanternBody",
        SOURCE / "lantern.png",
        2.05,
        (0.0, 0.0, -1.82),
        hook,
        cols=2,
        rows=6,
        uv_rect=(0.08, 0.0, 0.78, 0.83),
    )
    lantern.scale = (1.0, 1.0, 1.0)
    for frame, degrees in [(1, 0.0), (86, 2.2), (174, -1.6), (288, 1.1), (356, -3.4), (438, 1.3), (520, -0.55), (600, 0.0)]:
        hook.rotation_euler[1] = math.radians(degrees)
        hook.keyframe_insert("rotation_euler", index=1, frame=frame)
    set_bezier(hook.animation_data.action)


def animate_waterfall(parent, name, position, width, phase):
    water, _, _ = make_grid_card(
        name,
        SOURCE / "waterfall.png",
        width,
        position,
        parent,
        cols=4,
        rows=14,
    )
    cols = 4
    rows = 14

    def flow(sign):
        def deform(index, point):
            row = index // (cols + 1)
            col = index % (cols + 1)
            u = col / cols
            v = row / rows
            edge = math.sin(u * math.pi)
            point.x += sign * 0.09 * edge * math.sin(v * math.pi * 3.0 + u * 2.0)
            point.z += 0.06 * math.sin(v * math.pi * 4.0 + sign)
            return point

        return deform

    flow_a = add_shape(water, "FlowA", flow(1.0))
    flow_b = add_shape(water, "FlowB", flow(-1.0))
    points_a = [(1, 0.0), (55 + phase, 0.72), (110 + phase, 0.0), (175 + phase, 0.58), (245 + phase, 0.0), (330 + phase, 0.78), (410 + phase, 0.0), (505 + phase, 0.54), (600, 0.0)]
    points_b = [(1, 0.0), (85 + phase, 0.0), (140 + phase, 0.66), (205 + phase, 0.0), (285 + phase, 0.72), (365 + phase, 0.0), (455 + phase, 0.62), (545 + phase, 0.0), (600, 0.0)]
    key_value(flow_a, [(min(FRAME_END, f), v) for f, v in points_a])
    key_value(flow_b, [(min(FRAME_END, f), v) for f, v in points_b])
    set_bezier(water.data.shape_keys.animation_data.action)


def animate_cloud(parent, name, position, width, frame_offset, filename="clouds.png"):
    cloud, _, _ = make_grid_card(name, SOURCE / filename, width, position, parent)
    start_x = position[0]
    for frame, x in [(1, start_x), (210 + frame_offset, start_x + 0.55), (430 + frame_offset, start_x + 1.1), (600, start_x + 1.45)]:
        cloud.location.x = x
        cloud.keyframe_insert("location", index=0, frame=min(frame, FRAME_END))
    set_bezier(cloud.animation_data.action)


def animate_kite(parent, name, position, width, frame_offset):
    kite, _, _ = make_grid_card(name, SOURCE / "kite.png", width, position, parent)
    start_x, _, start_z = position
    motion = [
        (1, start_x, start_z, -4.0),
        (105 + frame_offset, start_x + 0.34, start_z + 0.12, 3.0),
        (225 + frame_offset, start_x + 0.05, start_z - 0.10, -2.0),
        (365 + frame_offset, start_x + 0.48, start_z + 0.18, 5.0),
        (485 + frame_offset, start_x + 0.22, start_z - 0.04, -3.0),
        (600, start_x, start_z, -4.0),
    ]
    for frame, x, z, degrees in motion:
        frame = min(frame, FRAME_END)
        kite.location.x = x
        kite.location.z = z
        kite.rotation_euler[1] = math.radians(degrees)
        kite.keyframe_insert("location", index=0, frame=frame)
        kite.keyframe_insert("location", index=2, frame=frame)
        kite.keyframe_insert("rotation_euler", index=1, frame=frame)
    set_bezier(kite.animation_data.action)


def build_scene():
    clear_scene()
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 540
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.render.fps = FPS
    scene.frame_start = FRAME_START
    scene.frame_end = FRAME_END
    scene.world.color = (0.58, 0.82, 0.84)

    far_root = bpy.data.objects.new("ZEN_FAR", None)
    mid_root = bpy.data.objects.new("ZEN_MID", None)
    near_root = bpy.data.objects.new("ZEN_NEAR", None)
    for root in (far_root, mid_root, near_root):
        bpy.context.collection.objects.link(root)

    far_sections = ["far.png", "far_1_blend.png", "far_2_blend.png", "far_3_blend.png", "far_4_blend.png", "far_5_blend.png"]
    for index, filename in enumerate(far_sections):
        make_grid_card(
            f"FarPlate{index}",
            SOURCE / filename,
            VIEW_W,
            (0.0, 3.0 - index * 0.002, VIEW_CENTER_Z + index * SECTION_STEP_Z),
            far_root,
            alpha=index != 0,
        )
    animate_cloud(far_root, "CloudBankA", (-0.9, 2.55, 6.2), 4.8, 0)
    animate_cloud(far_root, "CloudBankB", (-2.8, 2.50, 3.7), 3.5, -80)
    animate_cloud(far_root, "CloudSeam01", (-1.7, 2.34, 9.95), 6.7, -35)
    animate_cloud(far_root, "CloudSeam12", (-2.0, 2.32, 19.65), 6.7, 30)
    animate_cloud(far_root, "CloudSeam23", (-1.8, 2.30, 29.35), 6.7, -20, "clouds_sunset.png")
    animate_cloud(far_root, "CloudSeam34", (-1.4, 2.28, 39.05), 6.7, 10, "clouds_sunset.png")
    animate_cloud(far_root, "CloudSeam45", (-2.0, 2.26, 48.75), 6.7, -60, "clouds_night.png")
    make_grid_card("MidCliffs", SOURCE / "mid.png", VIEW_W, (0.0, -0.4, VIEW_CENTER_Z), mid_root)
    animate_kite(mid_root, "CraneKiteA", (-1.75, -0.72, 26.2), 1.35, 0)
    animate_kite(mid_root, "CraneKiteB", (1.45, -0.70, 35.8), 1.05, -45)
    animate_waterfall(mid_root, "WaterfallLeft", (-1.65, -0.8, 5.55), 0.72, 0)
    animate_waterfall(mid_root, "WaterfallRight", (1.68, -0.78, 4.75), 0.86, 36)
    make_grid_card("NearTerrace", SOURCE / "near.png", VIEW_W, (0.0, -2.0, VIEW_CENTER_Z - 0.40), near_root)
    animate_sakura(near_root)
    animate_lantern(near_root)

    bpy.ops.object.camera_add(location=(0.0, -18.5, VIEW_CENTER_Z))
    camera = bpy.context.object
    camera.name = "ReviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = VIEW_H
    camera.rotation_euler = (math.radians(90), 0.0, 0.0)
    scene.camera = camera

    light_data = bpy.data.lights.new("ReviewSun", type="AREA")
    light_data.energy = 650.0
    light_data.color = (1.0, 0.78, 0.56)
    light_data.shape = "DISK"
    light_data.size = 6.0
    light = bpy.data.objects.new("ReviewSun", light_data)
    bpy.context.collection.objects.link(light)
    light.location = (-4.0, -8.0, 12.0)
    light.rotation_euler = (math.radians(32), 0.0, math.radians(-24))

    scene.frame_set(int(os.environ.get("BT_FRAME", "1")))
    scene.render.filepath = str(REVIEW / f"preview_{scene.frame_current:04d}.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(REVIEW / "zen_blender_v2.blend"))
    bpy.ops.render.render(write_still=True)

    for obj in (camera, light):
        obj.hide_render = True
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT),
        export_format="GLB",
        export_animations=True,
        export_morph=True,
        export_cameras=False,
        export_lights=False,
    )


build_scene()
