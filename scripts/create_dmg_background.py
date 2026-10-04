#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

def generate_dmg_background(output_path):
    width, height = 1320, 840  # 2x Retina for 660x420 window
    img = Image.new("RGB", (width, height), "#FFFFFF")
    draw = ImageDraw.Draw(img)

    # Soft subtle blush pastel gradient background
    for y in range(height):
        ratio = y / height
        r = int(255 - (255 - 254) * ratio)
        g = int(247 - (247 - 250) * ratio)
        b = int(250 - (250 - 255) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    # Top accent bar (Tidy primary rose/pink #FB7185)
    draw.rectangle([(0, 0), (width, 8)], fill="#FB7185")

    # Font loader
    font_paths = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc"
    ]
    font_file = None
    for p in font_paths:
        if os.path.exists(p):
            font_file = p
            break

    try:
        font_large = ImageFont.truetype(font_file, 40)
        font_sub = ImageFont.truetype(font_file, 26)
        font_card_title = ImageFont.truetype(font_file, 28)
        font_card_body = ImageFont.truetype(font_file, 24)
        font_pill = ImageFont.truetype(font_file, 22)
    except Exception:
        font_large = ImageFont.load_default()
        font_sub = font_large
        font_card_title = font_large
        font_card_body = font_large
        font_pill = font_large

    # Drag & Drop guidance arrow between icons (Y ~ 280)
    arrow_color = "#FDA4AF" # Soft Rose
    arrow_y = 280
    draw.line([(440, arrow_y), (880, arrow_y)], fill=arrow_color, width=8)
    
    # Arrow head
    draw.polygon([(880, arrow_y - 20), (920, arrow_y), (880, arrow_y + 20)], fill=arrow_color)

    # Pill badge over arrow
    pill_box = [(580, arrow_y - 32), (780, arrow_y + 32)]
    draw.rounded_rectangle(pill_box, radius=32, fill="#FFE4E6", outline="#FDA4AF", width=3)
    draw.text((680, arrow_y), "DRAG TO INSTALL", fill="#BE123C", font=font_pill, anchor="mm")

    # Instructions Card at bottom
    card_x0, card_y0 = 60, 480
    card_x1, card_y1 = width - 60, height - 70
    draw.rounded_rectangle([(card_x0, card_y0), (card_x1, card_y1)], radius=24, fill="#FFFFFF", outline="#FCE7F3", width=4)

    # Card Left Accent Stripe
    draw.rounded_rectangle([(card_x0, card_y0), (card_x0 + 16, card_y1)], radius=12, fill="#FB7185")

    # Instructions text
    title_text = "💡  First time opening Tidy on macOS?"
    draw.text((card_x0 + 40, card_y0 + 40), title_text, fill="#1F2937", font=font_card_title, anchor="lm")

    body_1 = "• Option 1: Double-click '⚡️ Click Here to Open Tidy' below to launch instantly."
    body_2 = "• Option 2: Go to System Settings → Privacy & Security → Scroll to Security → Click 'Open Anyway'."
    draw.text((card_x0 + 40, card_y0 + 110), body_1, fill="#4B5563", font=font_card_body, anchor="lm")
    draw.text((card_x0 + 40, card_y0 + 180), body_2, fill="#4B5563", font=font_card_body, anchor="lm")

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    img.save(output_path, "PNG", dpi=(144, 144))
    print(f"DMG Background generated at: {output_path}")

if __name__ == "__main__":
    generate_dmg_background("/Users/saketkesar/Downloads/dinly/Tidy/Resources/dmg_background.png")
