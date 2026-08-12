import math
import pathlib

from PIL import Image

OUT = pathlib.Path(__file__).parent / "out"
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 512


def radial(name, inner, outer, power, core=0.14):
    image = Image.new("RGBA", (SIZE, SIZE))
    pixels = image.load()
    centre = SIZE / 2
    for y in range(SIZE):
        dy = (y - centre) / centre
        for x in range(SIZE):
            dx = (x - centre) / centre
            distance = math.sqrt(dx * dx + dy * dy)
            if distance >= 1:
                continue
            falloff = (1 - distance) ** power
            hot = max(0.0, 1 - distance / core) ** 2
            red = int(min(255, inner[0] * hot + outer[0] * (1 - hot)))
            green = int(min(255, inner[1] * hot + outer[1] * (1 - hot)))
            blue = int(min(255, inner[2] * hot + outer[2] * (1 - hot)))
            pixels[x, y] = (red, green, blue, int(255 * falloff))
    image.save(OUT / f"{name}.png", optimize=True)
    return image


def ring(name, colour, radius=0.62, width=0.09):
    image = Image.new("RGBA", (SIZE, SIZE))
    pixels = image.load()
    centre = SIZE / 2
    for y in range(SIZE):
        dy = (y - centre) / centre
        for x in range(SIZE):
            dx = (x - centre) / centre
            distance = math.sqrt(dx * dx + dy * dy)
            offset = abs(distance - radius) / width
            if offset >= 1:
                continue
            alpha = (1 - offset) ** 2
            pixels[x, y] = (colour[0], colour[1], colour[2], int(255 * alpha))
    image.save(OUT / f"{name}.png", optimize=True)


radial("GlowCold", (255, 255, 255), (75, 227, 255), 2.2)
radial("GlowGold", (255, 255, 245), (255, 178, 60), 2.0)
radial("GlowNeon", (255, 240, 255), (180, 75, 255), 2.6)
ring("RingFlash", (120, 230, 255))
print("sprites written to", OUT)
