#!/usr/bin/env python3
import os
import subprocess
import glob

def main():
    root = "/Users/saketkesar/Downloads/dinly/Tidy"
    resources_icons = os.path.join(root, "Resources/icons")
    os.makedirs(resources_icons, exist_ok=True)
    
    # 1. Convert all SVGs in tidy-icons to 128x128 PNGs
    svg_files = glob.glob(os.path.join(root, "tidy-icons", "*.svg"))
    print(f"Found {len(svg_files)} SVG icons to convert...")
    for svg_path in svg_files:
        base_name = os.path.splitext(os.path.basename(svg_path))[0]
        if base_name.startswith("_"):
            continue
        png_out = os.path.join(resources_icons, f"{base_name}.png")
        try:
            subprocess.run([
                "magick", "-background", "none", "-density", "300",
                svg_path, "-resize", "128x128", png_out
            ], check=True)
            print(f"Rendered {base_name}.png")
        except Exception as e:
            print(f"Failed to render {base_name}: {e}")

    # 2. Generate AppIcon.icns
    app_icon_svg = os.path.join(root, "tidy-icon.svg")
    iconset_dir = "/tmp/Tidy.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    icon_specs = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    
    for sz, name in icon_specs:
        out = os.path.join(iconset_dir, name)
        subprocess.run([
            "magick", "-background", "none", "-density", "300",
            app_icon_svg, "-resize", f"{sz}x{sz}", out
        ], check=True)
    
    icns_dst = os.path.join(root, "Resources/AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_dst], check=True)
    print(f"Generated {icns_dst} successfully!")

if __name__ == "__main__":
    main()
