import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "App" / "Assets.xcassets"


def imageset(name, source, scales=("universal",)):
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    for stale in folder.glob("*.png"):
        stale.unlink()
    filename = f"{name}.png"
    shutil.copy(source, folder / filename)
    contents = {
        "images": [{"filename": filename, "idiom": "universal", "scale": scale}
                   if scale != "universal" else
                   {"filename": filename, "idiom": "universal"}
                   for scale in scales],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2))
    return folder


def main():
    installed = []
    for argument in sys.argv[1:]:
        name, _, path = argument.partition("=")
        source = pathlib.Path(path)
        if not source.exists():
            print(f"missing: {source}")
            continue
        imageset(name, source)
        installed.append(f"{name} ({source.stat().st_size // 1024} KB)")
    print("installed:", ", ".join(installed) if installed else "nothing")


if __name__ == "__main__":
    main()
