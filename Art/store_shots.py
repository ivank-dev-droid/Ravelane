import pathlib
import shutil

from PIL import Image

SOURCE = pathlib.Path("/home/ivan/Загрузки/GIPSY/ios/Ravelane/Архив (3)")
ROOT = pathlib.Path("/home/ivan/Загрузки/GIPSY/ios/Ravelane/screenshots")

SIZES = {
    "6.9-inch": (1320, 2868),
    "6.5-inch": (1242, 2688),
}


def prepare(image, size):
    target_ratio = size[0] / size[1]
    ratio = image.width / image.height

    if abs(ratio - target_ratio) < 0.004:
        return image.resize(size, Image.LANCZOS)

    if ratio > target_ratio:
        width = int(round(image.height * target_ratio))
        left = (image.width - width) // 2
        cropped = image.crop((left, 0, left + width, image.height))
    else:
        height = int(round(image.width / target_ratio))
        top = (image.height - height) // 2
        cropped = image.crop((0, top, image.width, top + height))
    return cropped.resize(size, Image.LANCZOS)


shots = sorted(p for p in SOURCE.iterdir()
               if p.suffix.lower() == ".png" and not p.name.startswith("."))
print(f"source shots: {len(shots)}")

for folder, size in SIZES.items():
    destination = ROOT / folder
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)

    for index, path in enumerate(shots, start=1):
        image = Image.open(path)
        if image.mode in ("RGBA", "LA", "P"):
            flat = Image.new("RGB", image.size, (0, 0, 0))
            converted = image.convert("RGBA")
            flat.paste(converted, mask=converted.split()[-1])
            image = flat
        else:
            image = image.convert("RGB")

        prepared = prepare(image, size)
        target = destination / f"{index:02d}.png"
        prepared.save(target, "PNG", optimize=True)
        print(f"  {folder}/{target.name}  {prepared.size[0]}x{prepared.size[1]}  "
              f"{prepared.mode}  {target.stat().st_size // 1024} KB")
