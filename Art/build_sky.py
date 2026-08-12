from PIL import Image, ImageFilter, ImageOps
import pathlib

RAW = pathlib.Path(__file__).parent / "raw"
OUT = pathlib.Path(__file__).parent / "out"
OUT.mkdir(parents=True, exist_ok=True)

EQUIRECT = (4096, 2048)
TOP_ELEVATION = 55.0
BOTTOM_ELEVATION = -15.0


def elevation_to_row(elevation, height):
    return int(round((90.0 - elevation) / 180.0 * height))


source = Image.open(RAW / "sky_panorama.png").convert("RGB")
seamless = Image.new("RGB", (source.width * 2, source.height))
seamless.paste(source, (0, 0))
seamless.paste(ImageOps.mirror(source), (source.width, 0))

top_row = elevation_to_row(TOP_ELEVATION, EQUIRECT[1])
bottom_row = elevation_to_row(BOTTOM_ELEVATION, EQUIRECT[1])
band_height = bottom_row - top_row

band = seamless.resize((EQUIRECT[0], band_height), Image.LANCZOS)
canvas = Image.new("RGB", EQUIRECT)
canvas.paste(band, (0, top_row))

above = band.crop((0, 0, EQUIRECT[0], 1)).resize((EQUIRECT[0], top_row), Image.NEAREST)
canvas.paste(above, (0, 0))

below = band.crop((0, band_height - 1, EQUIRECT[0], band_height))
canvas.paste(below.resize((EQUIRECT[0], EQUIRECT[1] - bottom_row), Image.NEAREST), (0, bottom_row))

blurred = canvas.filter(ImageFilter.GaussianBlur(radius=3))
mask = Image.linear_gradient("L").resize(EQUIRECT)
canvas = Image.composite(canvas, blurred, mask.point(lambda v: 255 if v > 96 else v * 2))

canvas.save(OUT / "SkyDome.png", optimize=True)
print("sky dome:", canvas.size, (OUT / "SkyDome.png").stat().st_size // 1024, "KB")
