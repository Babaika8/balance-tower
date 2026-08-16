from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "art_review" / "zen_16bit_v2"
OUT = ROOT / "assets" / "skins" / "zen" / "v2"

SECTION_SOURCES = [
    REVIEW / "start_clean_source.png",
    REVIEW / "chapter_shrine_source.png",
    REVIEW / "chapter_monastery_source.png",
    REVIEW / "chapter_clouds_source.png",
    REVIEW / "chapter_zenith_source.png",
]


def pixel_section(source: Path, destination: Path, fade_bottom: bool) -> None:
    image = Image.open(source).convert("RGB")
    crop_width = round(image.height * 9 / 16)
    left = (image.width - crop_width) // 2
    image = image.crop((left, 0, left + crop_width, image.height))
    image = image.resize((360, 640), Image.Resampling.LANCZOS)
    image = image.resize((720, 1280), Image.Resampling.NEAREST).convert("RGBA")
    if fade_bottom:
        pixels = image.load()
        fade_height = 128
        for y in range(image.height - fade_height, image.height):
            alpha = round(255 * (image.height - 1 - y) / (fade_height - 1))
            for x in range(image.width):
                r, g, b, _ = pixels[x, y]
                pixels[x, y] = (r, g, b, alpha)
    image.save(destination)


def remove_connected_checker(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    seen = bytearray(width * height)
    queue = deque()

    def is_checker(x: int, y: int) -> bool:
        r, g, b, _ = pixels[x, y]
        return min(r, g, b) >= 225 and max(r, g, b) - min(r, g, b) <= 18

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if seen[index] or not is_checker(x, y):
            continue
        seen[index] = 1
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    return rgba


def split_stones(source: Path) -> None:
    sheet = Image.open(source).convert("RGB")
    cell_width = sheet.width // 4
    row_ranges = [(225, 485), (510, 785)]
    output_names = [
        "stone_1.png", "stone_2.png", "stone_3.png", "stone_4.png",
        "stone_5.png", "stone_6.png", "stone_7.png", "stone_8.png",
    ]
    index = 0
    for top, bottom in row_ranges:
        for column in range(4):
            cell = sheet.crop((column * cell_width, top, (column + 1) * cell_width, bottom))
            cell = remove_connected_checker(cell)
            alpha = cell.getchannel("A")
            bounds = alpha.getbbox()
            if bounds is None:
                raise RuntimeError(f"No stone found in cell {index}")
            stone = cell.crop(bounds).resize((176, 54), Image.Resampling.NEAREST)
            canvas = Image.new("RGBA", (180, 56), (0, 0, 0, 0))
            canvas.alpha_composite(stone, (2, 1))
            canvas.save(OUT / output_names[index])
            index += 1


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for index, source in enumerate(SECTION_SOURCES):
        pixel_section(source, OUT / f"chapter_{index}.png", index > 0)
    split_stones(REVIEW / "stones_sheet_source.png")


if __name__ == "__main__":
    main()
