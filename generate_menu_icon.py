#!/usr/bin/env python3
"""生成菜单栏专用图标 (template image, 22x22, 白色)"""
from PIL import Image, ImageDraw, ImageFont
import math

# 菜单栏图标尺寸
SIZE = 44  # @2x
img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

cx, cy = SIZE // 2, SIZE // 2

# 小跑马灯圆点 (8个)
num = 8
ring_r = 16
for i in range(num):
    angle = (i / num) * 2 * math.pi - math.pi / 2
    x = cx + ring_r * math.cos(angle)
    y = cy + ring_r * math.sin(angle)
    # 白色圆点
    draw.ellipse([x - 3.5, y - 3.5, x + 3.5, y + 3.5], fill=(255, 255, 255, 255))

# 中间 C
try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Black.ttf", 22)
except:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 22)

bbox = draw.textbbox((0, 0), "C", font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
tx = (SIZE - tw) // 2 - bbox[0]
ty = (SIZE - th) // 2 - bbox[1] - 1
draw.text((tx, ty), "C", font=font, fill=(255, 255, 255, 255))

img.save('Resources/menu_icon.png', 'PNG')
print("✓ 菜单栏图标生成 → Resources/menu_icon.png")
