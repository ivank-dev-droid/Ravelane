import binascii
import pathlib
import struct
import sys

from io import BytesIO

from PIL import Image

from glb import GLB


def shrink(payload, edge=1024, quality=86):
    image = Image.open(BytesIO(payload)).convert("RGB")
    if max(image.size) > edge:
        ratio = edge / max(image.size)
        image = image.resize((int(image.width * ratio), int(image.height * ratio)), Image.LANCZOS)
    buffer = BytesIO()
    image.save(buffer, "JPEG", quality=quality, optimize=True)
    return buffer.getvalue()


def bounds(points):
    lows = [min(point[axis] for point in points) for axis in range(3)]
    highs = [max(point[axis] for point in points) for axis in range(3)]
    return lows, highs


def normalise(positions, normals, target_length):
    lows, highs = bounds(positions)
    spans = [highs[axis] - lows[axis] for axis in range(3)]

    swap = spans[0] > spans[2]
    if swap:
        positions = [(point[2], point[1], -point[0]) for point in positions]
        normals = [(vector[2], vector[1], -vector[0]) for vector in normals]
        lows, highs = bounds(positions)
        spans = [highs[axis] - lows[axis] for axis in range(3)]

    length = spans[2] or 1
    scale = target_length / length
    centre_x = (lows[0] + highs[0]) / 2
    centre_z = (lows[2] + highs[2]) / 2

    moved = [((point[0] - centre_x) * scale,
              (point[1] - lows[1]) * scale,
              (point[2] - centre_z) * scale) for point in positions]

    front = [abs(point[0]) for point in moved if point[2] > spans[2] * scale * 0.35]
    rear = [abs(point[0]) for point in moved if point[2] < -spans[2] * scale * 0.35]
    nose_is_positive = (sum(front) / max(1, len(front))) < (sum(rear) / max(1, len(rear)))

    if not nose_is_positive:
        moved = [(-point[0], point[1], -point[2]) for point in moved]
        normals = [(-vector[0], vector[1], -vector[2]) for vector in normals]

    return moved, normals, scale


def usda(positions, normals, uvs, indices, texture_name, material_name):
    points = ", ".join(f"({p[0]:.4f}, {p[1]:.4f}, {p[2]:.4f})" for p in positions)
    vectors = ", ".join(f"({n[0]:.3f}, {n[1]:.3f}, {n[2]:.3f})" for n in normals)
    coords = ", ".join(f"({u[0]:.4f}, {1 - u[1]:.4f})" for u in uvs)
    faces = ", ".join(str(value) for value in indices)
    counts = ", ".join("3" for _ in range(len(indices) // 3))

    return f"""#usda 1.0
(
    defaultPrim = "Car"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Car"
{{
    def Mesh "Body" (
        prepend apiSchemas = ["MaterialBindingAPI"]
    )
    {{
        uniform bool doubleSided = 0
        int[] faceVertexCounts = [{counts}]
        int[] faceVertexIndices = [{faces}]
        point3f[] points = [{points}]
        normal3f[] normals = [{vectors}] (
            interpolation = "vertex"
        )
        texCoord2f[] primvars:st = [{coords}] (
            interpolation = "vertex"
        )
        rel material:binding = </Car/{material_name}>
        uniform token subdivisionScheme = "none"
    }}

    def Material "{material_name}"
    {{
        token outputs:surface.connect = </Car/{material_name}/Surface.outputs:surface>

        def Shader "Surface"
        {{
            uniform token info:id = "UsdPreviewSurface"
            color3f inputs:diffuseColor.connect = </Car/{material_name}/Albedo.outputs:rgb>
            float inputs:metallic = 0.35
            float inputs:roughness = 0.42
            float inputs:clearcoat = 0.6
            float inputs:clearcoatRoughness = 0.12
            token outputs:surface
        }}

        def Shader "Primvar"
        {{
            uniform token info:id = "UsdPrimvarReader_float2"
            token inputs:varname = "st"
            float2 outputs:result
        }}

        def Shader "Albedo"
        {{
            uniform token info:id = "UsdUVTexture"
            asset inputs:file = @{texture_name}@
            float2 inputs:st.connect = </Car/{material_name}/Primvar.outputs:result>
            token inputs:wrapS = "repeat"
            token inputs:wrapT = "repeat"
            float3 outputs:rgb
        }}
    }}
}}
"""


def pack(destination, entries):
    ALIGN = 64
    output = bytearray()
    directory = []

    for name, payload in entries:
        encoded = name.encode()
        crc = binascii.crc32(payload) & 0xFFFFFFFF
        header_length = 30 + len(encoded)
        padding = (-(len(output) + header_length)) % ALIGN
        offset = len(output)
        output += struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, 0, 0, 0, 0,
                              crc, len(payload), len(payload), len(encoded), padding)
        output += encoded
        output += b"\0" * padding
        output += payload
        directory.append((encoded, crc, len(payload), offset))

    start = len(output)
    for encoded, crc, size, offset in directory:
        output += struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 20, 20, 0, 0, 0, 0,
                              crc, size, size, len(encoded), 0, 0, 0, 0, 0, offset)
        output += encoded
    end = len(output)
    output += struct.pack("<IHHHHIIH", 0x06054B50, 0, 0,
                          len(directory), len(directory), end - start, start, 0)

    pathlib.Path(destination).write_bytes(bytes(output))
    return len(output)


def convert(source, destination, target_length):
    model = GLB(source)
    document = model.json
    primitive = document["meshes"][0]["primitives"][0]
    attributes = primitive["attributes"]

    positions = model.accessor(attributes["POSITION"])
    normals = model.accessor(attributes["NORMAL"]) if "NORMAL" in attributes else [(0, 1, 0)] * len(positions)
    uvs = model.accessor(attributes["TEXCOORD_0"]) if "TEXCOORD_0" in attributes else [(0, 0)] * len(positions)
    indices = [value[0] for value in model.accessor(primitive["indices"])]

    positions, normals, scale = normalise(positions, normals, target_length)

    payload, mime = model.image(0)
    payload = shrink(payload)
    texture_name = "albedo.jpg"

    stem = pathlib.Path(destination).stem
    document_text = usda(positions, normals, uvs, indices, texture_name, "Paint")
    size = pack(destination, [(f"{stem}.usda", document_text.encode()), (texture_name, payload)])
    return len(positions), len(indices) // 3, scale, size


if __name__ == "__main__":
    source, destination, length = sys.argv[1], sys.argv[2], float(sys.argv[3])
    vertices, triangles, scale, size = convert(source, destination, length)
    print(f"{pathlib.Path(destination).name}: {vertices} verts, {triangles} tris, "
          f"scale {scale:.4f}, {size // 1024} KB")
