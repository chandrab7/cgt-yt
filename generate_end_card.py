#!/usr/bin/env python3
"""Generate end card for CGT YouTube video.

Composites: hero sunrise bg + dark overlay + portal screenshot in browser frame
+ QR code for iOS app + text CTAs + CGT branding.
"""

import qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1920, 1080
GREEN = (0, 224, 128)       # CGT accent green from portal
WHITE = (255, 255, 255)
LIGHT_GRAY = (180, 180, 180)
DARK = (18, 18, 24)

# --- Fonts ---
def load_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_NARROW_BOLD = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"

font_title = load_font(FONT_BOLD, 44)
font_heading = load_font(FONT_BOLD, 28)
font_url = load_font(FONT_REG, 22)
font_brand = load_font(FONT_NARROW_BOLD, 20)
font_cta = load_font(FONT_BOLD, 20)


def make_qr(url, size=220):
    """Generate a QR code image with green-on-transparent style."""
    qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_H,
                        box_size=10, border=2)
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color=(0, 224, 128), back_color=(18, 18, 24)).convert("RGBA")
    return img.resize((size, size), Image.LANCZOS)


def make_browser_frame(screenshot_path, frame_w=880, frame_h=520):
    """Wrap a screenshot in a minimal dark browser chrome frame."""
    shot = Image.open(screenshot_path).convert("RGBA")

    # Browser chrome dimensions
    chrome_h = 36
    total_h = frame_h + chrome_h
    radius = 12

    frame = Image.new("RGBA", (frame_w, total_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)

    # Dark rounded rect background
    draw.rounded_rectangle([0, 0, frame_w - 1, total_h - 1], radius=radius,
                           fill=(30, 30, 38, 230), outline=(60, 60, 70, 200), width=1)

    # Traffic light dots
    for i, color in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        cx = 20 + i * 22
        cy = chrome_h // 2
        draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=color)

    # URL bar
    bar_x, bar_y = 90, 8
    bar_w, bar_h = frame_w - 120, 20
    draw.rounded_rectangle([bar_x, bar_y, bar_x + bar_w, bar_y + bar_h],
                           radius=4, fill=(50, 50, 58, 200))
    url_font = load_font(FONT_REG, 13)
    draw.text((bar_x + 10, bar_y + 2), "cgt.chandrab.com", fill=LIGHT_GRAY, font=url_font)

    # Screenshot content area
    content_area = (frame_w, frame_h)
    shot_resized = shot.resize(content_area, Image.LANCZOS)
    frame.paste(shot_resized, (0, chrome_h))

    # Subtle shadow/glow effect - create a larger shadow image
    shadow_pad = 20
    shadow = Image.new("RGBA", (frame_w + shadow_pad * 2, total_h + shadow_pad * 2), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle([shadow_pad - 4, shadow_pad - 4,
                                   frame_w + shadow_pad + 4, total_h + shadow_pad + 4],
                                  radius=radius + 4, fill=(0, 224, 128, 25))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=12))
    shadow.paste(frame, (shadow_pad, shadow_pad), frame)

    return shadow


def draw_pill_button(draw, x, y, text, font, fg, bg, padding_x=20, padding_y=8):
    """Draw a rounded pill-shaped button."""
    bbox = font.getbbox(text)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    bw = tw + padding_x * 2
    bh = th + padding_y * 2
    draw.rounded_rectangle([x, y, x + bw, y + bh], radius=bh // 2, fill=bg)
    draw.text((x + padding_x, y + padding_y - 2), text, fill=fg, font=font)
    return bw, bh


def generate():
    # Load hero background
    bg = Image.open("hero_bg_frame.png").convert("RGBA")
    bg = bg.resize((W, H), Image.LANCZOS)

    # Dark gradient overlay - darker on right side for text readability
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_ov = ImageDraw.Draw(overlay)
    for x in range(W):
        # Gradient: 55% opacity on left, 75% on right
        alpha = int(140 + (x / W) * 50)
        draw_ov.line([(x, 0), (x, H)], fill=(10, 10, 18, alpha))

    bg = Image.alpha_composite(bg, overlay)

    # --- Subtle top accent line ---
    draw = ImageDraw.Draw(bg)
    for x in range(W):
        # Green gradient line at top, fading at edges
        edge_fade = min(x, W - x) / 200
        edge_fade = min(edge_fade, 1.0)
        alpha = int(120 * edge_fade)
        draw.line([(x, 0), (x, 3)], fill=(GREEN[0], GREEN[1], GREEN[2], alpha))

    # --- Browser frame with portal screenshot (left side) ---
    browser = make_browser_frame("portal_homepage_frame.png", frame_w=880, frame_h=495)
    browser_x = 60
    browser_y = 115
    bg.paste(browser, (browser_x, browser_y), browser)

    # --- Title ---
    draw = ImageDraw.Draw(bg)
    title_x = 80
    title_y = 42
    draw.text((title_x, title_y), "Get Started with", fill=WHITE, font=font_title)
    # "Chandra's Golf Tracker" in green
    get_started_w = font_title.getbbox("Get Started with ")[2]
    draw.text((title_x + get_started_w, title_y), "Chandra's Golf Tracker",
              fill=GREEN, font=font_title)

    # --- Right panel: CTAs ---
    panel_x = 1020
    panel_y = 160

    # --- iOS App Section ---
    # QR Code
    qr_img = make_qr("https://apps.apple.com/us/app/chandras-gt/id6639617072", size=200)
    qr_x = panel_x + 20
    qr_y = panel_y + 10
    bg.paste(qr_img, (qr_x, qr_y), qr_img)

    # Text next to QR
    text_x = qr_x + 230
    text_y = qr_y + 10

    draw.text((text_x, text_y), "Download the iOS App", fill=WHITE, font=font_heading)
    text_y += 42

    draw.text((text_x, text_y), "Scan the QR code or visit:", fill=LIGHT_GRAY, font=font_url)
    text_y += 32

    # App Store URL - styled as a subtle link
    draw.text((text_x, text_y), "apps.apple.com/us/app/", fill=GREEN, font=font_url)
    text_y += 28
    draw.text((text_x, text_y), "chandras-gt/id6639617072", fill=GREEN, font=font_url)

    text_y += 50
    # Apple-style badge hint
    draw_pill_button(draw, text_x, text_y, "Available on the App Store",
                     font_cta, DARK, GREEN)

    # --- Divider line ---
    div_y = qr_y + 240
    for x in range(panel_x, W - 80):
        fade = min(x - panel_x, W - 80 - x) / 80
        fade = min(fade, 1.0)
        alpha = int(60 * fade)
        draw.point((x, div_y), fill=(255, 255, 255, alpha))

    # --- Web Dashboard Section ---
    dash_y = div_y + 30

    draw.text((panel_x + 20, dash_y), "Try the Web Dashboard", fill=WHITE, font=font_heading)
    dash_y += 42

    draw.text((panel_x + 20, dash_y),
              "Full round analytics, shot maps, and strokes gained",
              fill=LIGHT_GRAY, font=font_url)
    dash_y += 32

    draw.text((panel_x + 20, dash_y), "cgt.chandrab.com", fill=GREEN,
              font=load_font(FONT_BOLD, 26))
    dash_y += 50

    draw_pill_button(draw, panel_x + 20, dash_y, "Open Dashboard",
                     font_cta, DARK, GREEN)

    # --- Bottom branding bar ---
    bar_y = H - 60
    # Subtle dark strip
    draw.rectangle([0, bar_y - 5, W, H], fill=(10, 10, 18, 180))

    brand_text = "CHANDRA'S GOLF TRACKER"
    brand_bbox = font_brand.getbbox(brand_text)
    brand_w = brand_bbox[2] - brand_bbox[0]
    draw.text(((W - brand_w) // 2, bar_y + 12), brand_text,
              fill=(255, 255, 255, 160), font=font_brand)

    # Small green dot before and after brand
    dot_y = bar_y + 22
    draw.ellipse([(W // 2 - brand_w // 2 - 18, dot_y - 3),
                  (W // 2 - brand_w // 2 - 12, dot_y + 3)], fill=GREEN)
    draw.ellipse([(W // 2 + brand_w // 2 + 12, dot_y - 3),
                  (W // 2 + brand_w // 2 + 18, dot_y + 3)], fill=GREEN)

    # Save
    bg.save("end_card.png", "PNG")
    print("Generated end_card.png")


if __name__ == "__main__":
    generate()
