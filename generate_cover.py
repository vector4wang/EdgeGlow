#!/usr/bin/env python3
"""
Generate a professional WeChat Official Account cover image for EdgeGlow article.
Size: 900x383 pixels (2.35:1 aspect ratio)
"""

import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops, ImageEnhance

# --- Configuration ---
WIDTH = 900
HEIGHT = 383
OUTPUT_PATH = "/Users/wangxingchao/github/claude-edge-glow-swift/images/微信公众号封面.jpg"

random.seed(42)

# --- Font loading helper ---
def load_font(name, size):
    candidates = {
        'stheiti': ['/System/Library/Fonts/STHeiti Medium.ttc', '/System/Library/Fonts/STHeiti Light.ttc'],
        'hiragino': ['/System/Library/Fonts/Hiragino Sans GB.ttc'],
        'menlo': ['/System/Library/Fonts/Menlo.ttc'],
        'monaco': ['/System/Library/Fonts/Monaco.ttf'],
    }
    for path in candidates.get(name, []):
        try:
            return ImageFont.truetype(path, size)
        except:
            continue
    return ImageFont.load_default()


def create_background():
    """Create a rich dark tech background with radial gradient."""
    img = Image.new('RGB', (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(img)

    # Deep radial gradient from center
    cx, cy = WIDTH // 2, HEIGHT // 2
    max_dist = math.sqrt(cx**2 + cy**2)

    for y in range(HEIGHT):
        for x in range(0, WIDTH, 2):
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / max_dist
            r = int(8 + dist * 15)
            g = int(10 + dist * 18)
            b = int(28 + dist * 20)
            draw.line([(x, y), (x + 1, y)], fill=(r, g, b))

    return img


def create_background_fast():
    """Create dark tech background using gradient rectangles (faster)."""
    img = Image.new('RGB', (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(img)

    # Vertical gradient bands
    for y in range(HEIGHT):
        # Slight radial feel: darker at corners, slightly lighter at center
        t = y / HEIGHT
        # Base dark blue
        r = int(8 + t * 12)
        g = int(12 + t * 10)
        b = int(32 + t * 15)
        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))

    # Center brightening
    overlay = Image.new('RGB', (WIDTH, HEIGHT), (0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    for i in range(50):
        val = max(0, 25 - i)
        color = (val // 3, val // 2, val)
        odraw.ellipse(
            [WIDTH // 2 - 300 + i * 6, HEIGHT // 2 - 100 + i * 2,
             WIDTH // 2 + 300 - i * 6, HEIGHT // 2 + 100 - i * 2],
            outline=color
        )
    img = ImageChops.add(img, overlay)

    return img


def create_multicolor_glow():
    """Create a vibrant multicolor neon glow around edges."""
    # Create glow layers for different colors
    glow = Image.new('RGB', (WIDTH, HEIGHT), (0, 0, 0))

    # Multiple glow passes with different colors - more vibrant
    glow_configs = [
        {'color': (0, 230, 255), 'radius': 25, 'passes': 35, 'offset': 8},    # Cyan (primary)
        {'color': (50, 100, 255), 'radius': 20, 'passes': 30, 'offset': 5},    # Blue
        {'color': (130, 40, 255), 'radius': 16, 'passes': 22, 'offset': 3},    # Purple
        {'color': (255, 60, 170), 'radius': 12, 'passes': 16, 'offset': 1},    # Pink
        {'color': (255, 140, 30), 'radius': 10, 'passes': 12, 'offset': 0},    # Orange (subtle warm accent)
    ]

    for config in glow_configs:
        color = config['color']
        passes = config['passes']
        offset = config['offset']

        layer = Image.new('RGB', (WIDTH, HEIGHT), (0, 0, 0))
        ldraw = ImageDraw.Draw(layer)

        for i in range(passes):
            m = offset + i * 1.2
            intensity = max(0, 1 - i / passes) ** 0.7  # Slower falloff for more spread
            c = tuple(int(v * intensity) for v in color)
            rect = [int(m), int(m), WIDTH - int(m), HEIGHT - int(m)]
            ldraw.rectangle(rect, outline=c, width=1)

        # Blur this color layer more aggressively for smoother glow
        blurred = layer.filter(ImageFilter.GaussianBlur(radius=config['radius']))
        glow = ImageChops.add(glow, blurred)
        # Add a second blur pass for extra softness
        glow = ImageChops.add(glow, layer.filter(ImageFilter.GaussianBlur(radius=config['radius'] // 2)))

    # Add sharp bright edge lines (core of the glow)
    sharp = Image.new('RGB', (WIDTH, HEIGHT), (0, 0, 0))
    sdraw = ImageDraw.Draw(sharp)
    for i in range(4):
        m = 8 - i
        sdraw.rectangle([int(m), int(m), WIDTH - int(m), HEIGHT - int(m)],
                        outline=(0, 210 + i * 12, 245 + i * 3), width=1)
    glow = ImageChops.add(glow, sharp)

    return glow


def create_screen_mockup():
    """Create a subtle screen/monitor outline in the center to suggest the glowing screen."""
    layer = Image.new('RGB', (WIDTH, HEIGHT), (0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Screen rectangle
    sw, sh = 340, 210
    sx = (WIDTH - sw) // 2
    sy = (HEIGHT - sh) // 2 - 5

    # Draw screen with rounded corners - very subtle
    radius = 10
    # Just the outline, very faint
    draw.rounded_rectangle([sx, sy, sx + sw, sy + sh], radius=radius,
                           outline=(15, 30, 50), width=1)

    # Very subtle inner area
    draw.rounded_rectangle([sx + 4, sy + 4, sx + sw - 4, sy + sh - 4],
                           radius=radius - 3, fill=(8, 12, 25))

    # Very faint glow around screen edges (just to hint at the concept)
    for i in range(4):
        alpha = max(0, 25 - i * 6)
        color = (0, int(alpha * 0.5), int(alpha * 0.7))
        draw.rounded_rectangle(
            [sx - i * 2, sy - i * 2, sx + sw + i * 2, sy + sh + i * 2],
            radius=radius + i * 2, outline=color, width=1
        )

    # Very light blur
    blurred = layer.filter(ImageFilter.GaussianBlur(radius=3))
    layer = ImageChops.add(layer, blurred)

    return layer


def draw_grid(draw):
    """Draw subtle tech grid."""
    grid_color = (18, 28, 48)
    dot_color = (25, 38, 60)
    spacing = 35

    for x in range(spacing, WIDTH, spacing):
        draw.line([(x, 0), (x, HEIGHT)], fill=grid_color, width=1)
    for y in range(spacing, HEIGHT, spacing):
        draw.line([(0, y), (WIDTH, y)], fill=grid_color, width=1)

    # Intersection dots
    for x in range(spacing, WIDTH, spacing):
        for y in range(spacing, HEIGHT, spacing):
            draw.ellipse([x - 1, y - 1, x + 2, y + 2], fill=dot_color)


def draw_circuit_traces(draw):
    """Draw tech-style circuit trace decorations."""
    trace_color = (25, 50, 80)
    node_color = (40, 90, 140)
    bright_node = (60, 140, 200)

    traces = [
        # Top right cluster
        {'path': [(650, 15), (750, 15), (750, 45), (830, 45)], 'end': (830, 45)},
        {'path': [(670, 30), (720, 30), (720, 60), (800, 60), (800, 80)], 'end': (800, 80)},
        {'path': [(700, 10), (700, 25)], 'end': (700, 25)},
        {'path': [(850, 30), (850, 90), (870, 90)], 'end': (870, 90)},

        # Bottom left cluster
        {'path': [(30, 340), (130, 340), (130, 360), (200, 360)], 'end': (200, 360)},
        {'path': [(50, 320), (50, 350), (100, 350)], 'end': (100, 350)},
        {'path': [(15, 360), (80, 360)], 'end': (80, 360)},
        {'path': [(20, 300), (20, 380)], 'end': (20, 380)},

        # Top left
        {'path': [(40, 30), (100, 30), (100, 50)], 'end': (100, 50)},
        {'path': [(20, 45), (80, 45)], 'end': (80, 45)},
    ]

    for trace in traces:
        path = trace['path']
        for i in range(len(path) - 1):
            draw.line([path[i], path[i + 1]], fill=trace_color, width=1)
        # Node at end
        ex, ey = trace['end']
        draw.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=node_color)
        draw.ellipse([ex - 1, ey - 1, ex + 2, ey + 2], fill=bright_node)

    # IC chip symbols
    chip_positions = [(760, 20), (810, 65), (60, 335), (110, 355)]
    for cx, cy in chip_positions:
        draw.rectangle([cx - 6, cy - 6, cx + 6, cy + 6], outline=node_color, width=1)
        # Pin lines
        for dx in [-8, -4, 0, 4, 8]:
            draw.line([(cx + dx, cy - 6), (cx + dx, cy - 9)], fill=trace_color, width=1)
            draw.line([(cx + dx, cy + 6), (cx + dx, cy + 9)], fill=trace_color, width=1)


def draw_code_snippets(draw):
    """Draw code snippet decorations with better visibility."""
    code_font = load_font('menlo', 10)
    code_color = (50, 90, 120)
    comment_color = (40, 80, 70)

    # Bottom right code block - more visible
    code_lines = [
        (".edgeGlow()", code_color),
        ("  .color(.cyan)", (40, 100, 130)),
        ("  .radius(12)", (40, 100, 130)),
        ("  .blur(20)", (40, 100, 130)),
    ]

    x_start = 700
    y_start = 280
    for i, (line, color) in enumerate(code_lines):
        y = y_start + i * 16
        draw.text((x_start, y), line, fill=color, font=code_font)

    # Top left comment
    comment_lines = [
        ("// SwiftUI", comment_color),
        ("// ViewModifier", comment_color),
    ]
    for i, (line, color) in enumerate(comment_lines):
        y = 12 + i * 16
        draw.text((12, y), line, fill=color, font=code_font)


def draw_hexagons(draw):
    """Draw decorative hexagons."""
    def draw_hex(cx, cy, r, color, width=1):
        points = []
        for i in range(6):
            angle = math.pi / 3 * i - math.pi / 6
            px = cx + r * math.cos(angle)
            py = cy + r * math.sin(angle)
            points.append((px, py))
        points.append(points[0])
        for j in range(6):
            draw.line([points[j], points[j + 1]], fill=color, width=width)

    hex_color = (25, 50, 75)
    hex_bright = (40, 80, 110)

    positions = [
        (70, 70, 18), (820, 100, 22), (90, 290, 15),
        (790, 260, 20), (450, 40, 12), (200, 350, 14),
        (680, 330, 16), (350, 30, 10),
    ]

    for cx, cy, r in positions:
        draw_hex(cx, cy, r, hex_color)
        draw_hex(cx, cy, r * 0.55, hex_bright)


def draw_particles(draw):
    """Add sparkle particles for tech atmosphere."""
    for _ in range(40):
        x = random.randint(5, WIDTH - 5)
        y = random.randint(5, HEIGHT - 5)
        size = random.randint(1, 2)
        b = random.randint(120, 255)
        color = (int(b * 0.2), int(b * 0.4), b)
        draw.ellipse([x, y, x + size, y + size], fill=color)

    # Brighter edge sparkles
    edge_sparkle_positions = []
    for _ in range(20):
        side = random.choice(['top', 'bottom', 'left', 'right'])
        if side == 'top':
            x = random.randint(30, WIDTH - 30)
            y = random.randint(3, 15)
        elif side == 'bottom':
            x = random.randint(30, WIDTH - 30)
            y = random.randint(HEIGHT - 15, HEIGHT - 3)
        elif side == 'left':
            x = random.randint(3, 15)
            y = random.randint(30, HEIGHT - 30)
        else:
            x = random.randint(WIDTH - 15, WIDTH - 3)
            y = random.randint(30, HEIGHT - 30)

        size = random.randint(2, 4)
        draw.ellipse([x, y, x + size, y + size], fill=(0, 200, 240))

    # Cross-shaped sparkles at a few positions
    sparkle_positions = [(100, 50), (800, 320), (750, 50), (150, 330)]
    for sx, sy in sparkle_positions:
        for dx in range(-4, 5):
            if abs(dx) > 0:
                alpha = max(50, 200 - abs(dx) * 40)
                draw.point((sx + dx, sy), fill=(0, int(alpha * 0.8), alpha))
                draw.point((sx, sy + dx), fill=(0, int(alpha * 0.8), alpha))


def draw_main_text(img):
    """Draw the main Chinese title with glow effect."""
    text_layer = Image.new('RGB', (WIDTH, HEIGHT), (0, 0, 0))
    text_draw = ImageDraw.Draw(text_layer)

    title = "我用 SwiftUI 做了个开源工具，"
    subtitle = "让 AI 编程时屏幕会「发光」"

    title_font = load_font('stheiti', 28)
    subtitle_font = load_font('stheiti', 32)

    # Calculate positions
    bbox1 = text_draw.textbbox((0, 0), title, font=title_font)
    tw1 = bbox1[2] - bbox1[0]
    x1 = (WIDTH - tw1) // 2

    bbox2 = text_draw.textbbox((0, 0), subtitle, font=subtitle_font)
    tw2 = bbox2[2] - bbox2[0]
    x2 = (WIDTH - tw2) // 2

    y1 = 110
    y2 = 165

    # Text glow - multiple passes
    glow_color = (0, 60, 100)
    for offset in range(-3, 4):
        for offset2 in range(-3, 4):
            if abs(offset) + abs(offset2) <= 3:
                text_draw.text((x1 + offset, y1 + offset2), title,
                              fill=glow_color, font=title_font)
                text_draw.text((x2 + offset, y2 + offset2), subtitle,
                              fill=(0, 50, 90), font=subtitle_font)

    # Main title text
    text_draw.text((x1, y1), title, fill=(230, 240, 255), font=title_font)

    # Subtitle with cyan emphasis
    # Draw "发光" in brighter cyan
    pre_text = "让 AI 编程时屏幕会"
    highlight = "「发光」"

    pre_bbox = text_draw.textbbox((0, 0), pre_text, font=subtitle_font)
    pre_w = pre_bbox[2] - pre_bbox[0]
    pre_x = x2

    text_draw.text((pre_x, y2), pre_text, fill=(220, 235, 255), font=subtitle_font)
    text_draw.text((pre_x + pre_w, y2), highlight, fill=(0, 230, 255), font=subtitle_font)

    return text_layer


def create_badge():
    """Create '开源免费' badge."""
    badge_w, badge_h = 80, 26
    badge = Image.new('RGB', (badge_w, badge_h), (0, 0, 0))
    bdraw = ImageDraw.Draw(badge)

    # Rounded rectangle background
    r = 13
    bdraw.rounded_rectangle([0, 0, badge_w - 1, badge_h - 1], radius=r,
                            fill=(0, 195, 115))

    # Inner lighter area
    bdraw.rounded_rectangle([2, 2, badge_w - 3, badge_h - 3], radius=r - 2,
                            fill=(0, 210, 130))

    # Text
    badge_font = load_font('stheiti', 14)
    text = "开源免费"
    bbox = bdraw.textbbox((0, 0), text, font=badge_font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    bx = (badge_w - tw) // 2
    by = (badge_h - th) // 2 - 2
    bdraw.text((bx, by), text, fill=(255, 255, 255), font=badge_font)

    return badge


def add_edgeglow_logo(draw):
    """Add EdgeGlow branding in bottom-right corner."""
    logo_font = load_font('menlo', 12)

    # Small icon (glowing dot)
    icon_x = WIDTH - 140
    icon_y = HEIGHT - 32
    draw.ellipse([icon_x, icon_y, icon_x + 8, icon_y + 8], fill=(0, 220, 255))
    # Outer glow ring
    draw.ellipse([icon_x - 2, icon_y - 2, icon_x + 10, icon_y + 10],
                 outline=(0, 150, 200), width=1)

    # Text
    logo_text = "EdgeGlow"
    # Shadow
    draw.text((icon_x + 14, icon_y + 1), logo_text, fill=(0, 0, 0), font=logo_font)
    # Main text
    draw.text((icon_x + 14, icon_y), logo_text, fill=(0, 210, 240), font=logo_font)


def draw_data_flow_lines(draw):
    """Draw subtle data flow lines connecting elements."""
    flow_color = (15, 35, 55)

    # Curved lines suggesting data flow
    for i in range(5):
        y = 60 + i * 60
        x_start = random.randint(100, 200)
        x_end = random.randint(700, 820)
        # Bezier-like curve using line segments
        points = [(x_start, y)]
        mid_x = (x_start + x_end) // 2
        mid_y = y + random.randint(-20, 20)
        for t in range(1, 10):
            frac = t / 10
            # Quadratic bezier
            px = int((1 - frac)**2 * x_start + 2 * (1 - frac) * frac * mid_x + frac**2 * x_end)
            py = int((1 - frac)**2 * y + 2 * (1 - frac) * frac * mid_y + frac**2 * y)
            points.append((px, py))

        for j in range(len(points) - 1):
            draw.line([points[j], points[j + 1]], fill=flow_color, width=1)


def add_vignette(img):
    """Add subtle vignette effect."""
    vignette = Image.new('L', (WIDTH, HEIGHT), 255)
    vdraw = ImageDraw.Draw(vignette)

    # Dark edges
    for i in range(100):
        alpha = int(i * 2.5)
        if alpha > 200:
            alpha = 200
        vdraw.rectangle([i, i, WIDTH - i, HEIGHT - i], outline=255 - alpha)

    vignette = vignette.filter(ImageFilter.GaussianBlur(radius=15))

    # Apply as mask
    img_copy = img.copy()
    img_copy.putalpha(vignette)

    # Create dark background for blending
    dark_bg = Image.new('RGB', (WIDTH, HEIGHT), (5, 8, 18))
    dark_bg.putalpha(Image.new('L', (WIDTH, HEIGHT), 0))

    result = Image.alpha_composite(dark_bg.convert('RGBA'), img_copy.convert('RGBA'))
    return result.convert('RGB')


def main():
    print("[1/10] Creating background...")
    img = create_background_fast()

    print("[2/10] Drawing grid...")
    draw = ImageDraw.Draw(img)
    draw_grid(draw)

    print("[3/10] Adding data flow lines...")
    draw_data_flow_lines(draw)

    print("[4/10] Adding circuit traces...")
    draw_circuit_traces(draw)

    print("[5/10] Adding hexagons...")
    draw_hexagons(draw)

    print("[6/10] Adding code snippets...")
    draw_code_snippets(draw)

    print("[7/10] Adding neon glow edges...")
    glow = create_multicolor_glow()
    img = ImageChops.add(img, glow)

    print("[8/10] Adding screen mockup...")
    screen = create_screen_mockup()
    img = ImageChops.add(img, screen)

    print("[9/10] Adding particles and text...")
    draw = ImageDraw.Draw(img)
    draw_particles(draw)

    text_layer = draw_main_text(img)
    img = ImageChops.add(img, text_layer)

    add_edgeglow_logo(draw)

    print("[10/10] Adding badge and finishing...")
    badge = create_badge()
    badge_x = WIDTH - badge.width - 25
    badge_y = 18
    img.paste(badge, (badge_x, badge_y))

    # Vignette
    img = add_vignette(img)

    # Slight contrast boost
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(1.15)

    # Slight saturation boost
    enhancer = ImageEnhance.Color(img)
    img = enhancer.enhance(1.2)

    # Final slight sharpen
    img = img.filter(ImageFilter.UnsharpMask(radius=1.5, percent=40))

    print(f"\nSaving to {OUTPUT_PATH}...")
    img.save(OUTPUT_PATH, 'JPEG', quality=95)
    print(f"Done! Image saved. Size: {img.size}")


if __name__ == "__main__":
    main()
