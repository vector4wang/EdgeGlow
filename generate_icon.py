#!/usr/bin/env python3
"""生成 EdgeGlow App 图标: 大写C + 跑马灯光环"""

from PIL import Image, ImageDraw, ImageFont
import math

SIZE = 1024
img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# macOS 圆角矩形背景
radius = 220
margin = 40
bg_rect = [margin, margin, SIZE - margin, SIZE - margin]
draw.rounded_rectangle(bg_rect, radius=radius, fill=(20, 20, 35, 255))

# 内部渐变效果 (用多个半透明圆叠加模拟)
cx, cy = SIZE // 2, SIZE // 2
for i in range(80):
    r = 400 - i * 4
    alpha = int(8 + i * 0.5)
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([cx - r, cy - r, cx + r, cy + r],
               fill=(40 + i, 30 + i // 2, 80 + i, alpha))
    img = Image.alpha_composite(img, overlay)

draw = ImageDraw.Draw(img)

# ============================================================
# 跑马灯 - 彩色圆点环绕
# ============================================================
num_lights = 24
ring_radius = 340
light_radius = 18

# 彩虹色
colors = [
    (170, 85, 247),   # 紫
    (100, 102, 241),  # 靛蓝
    (59, 130, 246),   # 蓝
    (6, 182, 212),    # 青
    (14, 165, 233),   # 天蓝
    (20, 184, 166),   # 绿松石
    (16, 185, 129),   # 绿
    (132, 204, 22),   # 黄绿
    (234, 179, 8),    # 黄
    (249, 115, 22),   # 橙
    (239, 68, 68),    # 红
    (236, 72, 153),   # 粉
    (217, 70, 239),   # 紫红
    (168, 85, 247),   # 紫 (回到开始)
    (100, 102, 241),
    (59, 130, 246),
    (6, 182, 212),
    (14, 165, 233),
    (20, 184, 166),
    (16, 185, 129),
    (132, 204, 22),
    (234, 179, 8),
    (249, 115, 22),
    (239, 68, 68),
]

# 画光晕层 (每盏灯的光晕)
for i in range(num_lights):
    angle = (i / num_lights) * 2 * math.pi - math.pi / 2
    lx = cx + ring_radius * math.cos(angle)
    ly = cy + ring_radius * math.sin(angle)

    color = colors[i % len(colors)]

    # 外层光晕 (大而模糊)
    glow_r = light_radius * 3
    glow_overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_overlay)
    for g in range(20):
        gr = int(glow_r * (1 - g / 20))
        ga = int(40 * (1 - g / 20))
        gd.ellipse([lx - gr, ly - gr, lx + gr, ly + gr],
                   fill=(*color, ga))
    img = Image.alpha_composite(img, glow_overlay)

draw = ImageDraw.Draw(img)

# 画灯珠 (实心亮色圆点)
for i in range(num_lights):
    angle = (i / num_lights) * 2 * math.pi - math.pi / 2
    lx = cx + ring_radius * math.cos(angle)
    ly = cy + ring_radius * math.sin(angle)

    color = colors[i % len(colors)]

    # 亮色核心
    r = light_radius
    draw.ellipse([lx - r, ly - r, lx + r, ly + r],
                 fill=(*color, 240))

    # 高光点
    hr = int(r * 0.4)
    hx, hy = lx - r * 0.2, ly - r * 0.3
    draw.ellipse([hx - hr, hy - hr, hx + hr, hy + hr],
                 fill=(255, 255, 255, 160))

# ============================================================
# 大写 C
# ============================================================
# 尝试使用系统字体
try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Black.ttf", 480)
except:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 480)
    except:
        font = ImageFont.load_default()

# 文字阴影
text = "C"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
tx = (SIZE - tw) // 2 - bbox[0]
ty = (SIZE - th) // 2 - bbox[1] - 15

# 阴影
shadow_overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow_overlay)
sd.text((tx + 4, ty + 4), text, font=font, fill=(0, 0, 0, 120))
img = Image.alpha_composite(img, shadow_overlay)

draw = ImageDraw.Draw(img)

# 渐变文字效果 - 用白色带一点蓝紫
draw.text((tx, ty), text, font=font, fill=(230, 235, 255, 255))

# 文字高光
highlight_overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
hd = ImageDraw.Draw(highlight_overlay)
hd.text((tx, ty - 2), text, font=font, fill=(255, 255, 255, 60))
img = Image.alpha_composite(highlight_overlay, img)

# ============================================================
# 保存
# ============================================================
img.save('Resources/EdgeGlow_1024.png', 'PNG')
print("✓ 图标生成完成 → Resources/EdgeGlow_1024.png")
