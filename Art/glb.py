import json
import struct
import pathlib

COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
             5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class GLB:
    def __init__(self, path):
        raw = pathlib.Path(path).read_bytes()
        magic, version, _ = struct.unpack_from("<III", raw, 0)
        assert magic == 0x46546C67, "not a glb"
        offset = 12
        self.json = None
        self.bin = b""
        while offset < len(raw):
            length, kind = struct.unpack_from("<II", raw, offset)
            chunk = raw[offset + 8: offset + 8 + length]
            if kind == 0x4E4F534A:
                self.json = json.loads(chunk)
            elif kind == 0x004E4942:
                self.bin = chunk
            offset += 8 + length + (-length % 4)

    def accessor(self, index):
        spec = self.json["accessors"][index]
        view = self.json["bufferViews"][spec["bufferView"]]
        fmt, size = COMPONENT[spec["componentType"]]
        count = COUNTS[spec["type"]]
        start = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
        stride = view.get("byteStride") or size * count
        values = []
        for index in range(spec["count"]):
            base = start + index * stride
            values.append(struct.unpack_from("<" + fmt * count, self.bin, base))
        return values

    def image(self, index):
        spec = self.json["images"][index]
        view = self.json["bufferViews"][spec["bufferView"]]
        start = view.get("byteOffset", 0)
        return self.bin[start: start + view["byteLength"]], spec.get("mimeType", "image/png")


if __name__ == "__main__":
    import sys
    model = GLB(sys.argv[1])
    document = model.json
    print("meshes:", len(document.get("meshes", [])))
    for mesh in document.get("meshes", []):
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            counts = {key: document["accessors"][value]["count"] for key, value in attributes.items()}
            print("  primitive", counts, "indices",
                  document["accessors"][primitive["indices"]]["count"] if "indices" in primitive else None,
                  "material", primitive.get("material"))
    print("materials:", json.dumps(document.get("materials", []))[:400])
    print("images:", [(i.get("mimeType"), document["bufferViews"][i["bufferView"]]["byteLength"])
                      for i in document.get("images", [])])
    print("nodes:", json.dumps(document.get("nodes", []))[:400])
