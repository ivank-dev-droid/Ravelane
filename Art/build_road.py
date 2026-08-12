import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageOps

RAW = pathlib.Path(__file__).parent / "raw"
OUT = pathlib.Path(__file__).parent / "out"
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 1024
CYAN = (75, 227, 255)
MAGENTA = (180, 75, 255)
GOLD = (255, 194, 75)


def vertically_seamless(image):
    half = image.crop((0, 0, image.width, image.height // 2))
    tile = Image.new(image.mode, image.size)
    tile.paste(half, (0, 0))
    tile.paste(ImageOps.flip(half), (0, image.height // 2))
    return tile


def base_colour(marks):
    source = Image.open(RAW / "road_tile.png").convert("RGB")
    source = source.resize((SIZE, SIZE), Image.LANCZOS)
    tile = vertically_seamless(source)
    tile = Image.eval(tile, lambda v: int(v * 0.30))
    painted = Image.blend(tile, marks, 0.62)
    mask = marks.convert("L").point(lambda v: min(255, v * 3))
    tile = Image.composite(painted, tile, mask)
    tile.save(OUT / "RoadBase.png", optimize=True)
    return tile


def normal_map(tile):
    height = tile.convert("L").filter(ImageFilter.GaussianBlur(radius=1))
    pixels = height.load()
    normal = Image.new("RGB", (SIZE, SIZE))
    target = normal.load()
    strength = 2.4
    for y in range(SIZE):
        up = pixels[0, (y - 1) % SIZE]
        for x in range(SIZE):
            left = pixels[(x - 1) % SIZE, y]
            right = pixels[(x + 1) % SIZE, y]
            up = pixels[x, (y - 1) % SIZE]
            down = pixels[x, (y + 1) % SIZE]
            dx = (left - right) / 255.0 * strength
            dy = (up - down) / 255.0 * strength
            length = math.sqrt(dx * dx + dy * dy + 1.0)
            target[x, y] = (
                int((dx / length * 0.5 + 0.5) * 255),
                int((dy / length * 0.5 + 0.5) * 255),
                int((1.0 / length * 0.5 + 0.5) * 255),
            )
    normal.save(OUT / "RoadNormal.png", optimize=True)


def markings():
    image = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(image)

    edge = int(SIZE * 0.045)
    draw.rectangle([0, 0, edge, SIZE], fill=MAGENTA)
    draw.rectangle([SIZE - edge - 1, 0, SIZE - 1, SIZE], fill=MAGENTA)

    inner = int(SIZE * 0.075)
    draw.rectangle([inner, 0, inner + 5, SIZE], fill=tuple(v // 3 for v in CYAN))
    draw.rectangle([SIZE - inner - 6, 0, SIZE - inner - 1, SIZE], fill=tuple(v // 3 for v in CYAN))

    dash = SIZE // 8
    for index in range(8):
        top = index * dash
        if index % 2 == 0:
            draw.rectangle([SIZE // 2 - 4, top, SIZE // 2 + 4, top + dash // 2], fill=CYAN)

    chevron_period = SIZE // 4
    span = int(SIZE * 0.16)
    for index in range(4):
        centre = index * chevron_period + chevron_period // 2
        for offset in (-1, 1):
            tip_x = SIZE // 2 + offset * span
            draw.line(
                [(SIZE // 2, centre + 42), (tip_x, centre - 30)],
                fill=GOLD, width=7
            )

    image = image.filter(ImageFilter.GaussianBlur(radius=1.2))
    image = ImageOps.flip(image)
    image.save(OUT / "RoadEmissive.png", optimize=True)
    return image


marks = markings()
tile = base_colour(marks)
normal_map(tile)
print("road textures written to", OUT)
