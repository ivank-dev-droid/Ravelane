import pathlib
import sys
from collections import deque

from PIL import Image, ImageFilter

TOLERANCE = 150
STEP = 9
FEATHER = 1.6


def cut(source, destination, size=512):
    image = Image.open(source).convert("RGB")
    width, height = image.size
    pixels = image.load()

    seeds = []
    for x in range(0, width, 4):
        seeds.append((x, 0))
        seeds.append((x, height - 1))
    for y in range(0, height, 4):
        seeds.append((0, y))
        seeds.append((width - 1, y))

    reference = [pixels[x, y] for x, y in seeds[:80]]
    average = tuple(sum(channel[index] for channel in reference) // len(reference) for index in range(3))

    background = bytearray(width * height)
    queue = deque()
    for x, y in seeds:
        index = y * width + x
        if not background[index]:
            background[index] = 1
            queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        here = pixels[x, y]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            index = ny * width + nx
            if background[index]:
                continue
            pixel = pixels[nx, ny]
            local = abs(pixel[0] - here[0]) + abs(pixel[1] - here[1]) + abs(pixel[2] - here[2])
            global_distance = abs(pixel[0] - average[0]) + abs(pixel[1] - average[1]) + abs(pixel[2] - average[2])
            if local <= STEP and global_distance <= TOLERANCE:
                background[index] = 1
                queue.append((nx, ny))

    mask = Image.frombytes("L", (width, height), bytes(255 - value * 255 for value in background))
    mask = mask.filter(ImageFilter.GaussianBlur(radius=FEATHER))

    result = image.convert("RGBA")
    result.putalpha(mask)
    result = result.resize((size, size), Image.LANCZOS)
    result.save(destination, optimize=True)
    covered = sum(background) / (width * height)
    return covered


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        source = pathlib.Path(argument)
        destination = source.parent.parent / "out" / f"{source.stem}.png"
        ratio = cut(source, destination)
        print(f"{source.name}: background {ratio * 100:.0f}% -> {destination.name}")
