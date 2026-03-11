#!/usr/bin/env python3
"""像素风精灵生成器 - 为像素深渊游戏生成所有美术资产"""
from PIL import Image, ImageDraw, ImageFilter
import os, math

BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  ✓ {os.path.relpath(path)}")

def p(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height and len(c) == 4 and c[3] > 0:
        img.putpixel((x, y), c)

def add_outline(img, color=(8, 6, 14, 255)):
    w, h = img.size
    src = img.copy()
    out = img.load()
    src_px = src.load()
    for y in range(h):
        for x in range(w):
            if src_px[x, y][3] == 0:
                for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < w and 0 <= ny < h and src_px[nx, ny][3] > 128:
                        out[x, y] = color
                        break
    return img

# ════════════════════════════════════════════════════════════
# TILES
# ════════════════════════════════════════════════════════════

def make_floor():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    # 暖灰棕色石板地面 — 和深紫墙壁形成明显色差
    BASE   = (52, 46, 42, 255)   # 基础暖灰棕
    TILE_A = (58, 52, 46, 255)   # 石板 A - 稍亮
    TILE_B = (54, 48, 44, 255)   # 石板 B
    GROUT  = (36, 30, 28, 255)   # 砖缝 - 深棕
    HI     = (68, 62, 54, 255)   # 高光
    HI2    = (76, 68, 58, 255)   # 亮高光
    DK     = (42, 36, 34, 255)   # 暗角

    for y in range(16):
        for x in range(16):
            img.putpixel((x, y), BASE)

    def slab(x0, y0, x1, y1, color):
        for yy in range(y0, y1+1):
            for xx in range(x0, x1+1):
                p(img, xx, yy, color)
        for xx in range(x0, x1+1):
            p(img, xx, y0, HI)
        for yy in range(y0, y1+1):
            p(img, x0, yy, HI)
        for xx in range(x0, x1+1):
            p(img, xx, y1, DK)
        for yy in range(y0, y1+1):
            p(img, x1, yy, DK)

    # 砖缝
    for x in range(16):
        p(img, x, 0, GROUT); p(img, x, 7, GROUT)
        p(img, x, 8, GROUT); p(img, x, 15, GROUT)
    for y in range(16):
        p(img, 0, y, GROUT); p(img, 15, y, GROUT)
    for y in range(0, 8):
        p(img, 8, y, GROUT)
    for y in range(8, 16):
        p(img, 4, y, GROUT); p(img, 11, y, GROUT)

    slab(1, 1, 7, 6, TILE_A)
    slab(9, 1, 14, 6, TILE_B)
    slab(1, 9, 3, 14, TILE_B)
    slab(5, 9, 10, 14, TILE_A)
    slab(12, 9, 14, 14, TILE_B)

    # 磨损高光和暗点
    for (x,y) in [(3,2),(6,4),(10,3),(13,5),(2,10),(7,12),(9,11),(14,13)]:
        p(img, x, y, HI2)
    for (x,y) in [(5,3),(11,2),(4,5),(12,6),(3,11),(8,13),(6,10),(13,12)]:
        p(img, x, y, DK)

    # 苔藓
    moss = (42, 50, 38, 255)
    for (x,y) in [(2,5),(11,4),(7,13),(14,10)]:
        p(img, x, y, moss)

    return img


def make_void():
    """围墙外部的深渊虚空纹理 — 极暗带微弱岩石纹理"""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    BASE = (8, 6, 14, 255)     # 极暗紫黑
    V1   = (12, 10, 20, 255)   # 微亮变化
    V2   = (6, 4, 10, 255)     # 更暗变化
    EDGE = (16, 14, 26, 255)   # 偶尔可见的岩壁纹理

    import random
    random.seed(101)
    for y in range(16):
        for x in range(16):
            r = random.random()
            if r < 0.08:
                img.putpixel((x, y), EDGE)
            elif r < 0.25:
                img.putpixel((x, y), V1)
            elif r < 0.40:
                img.putpixel((x, y), V2)
            else:
                img.putpixel((x, y), BASE)

    return img


def make_wall():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    # 深色石砖墙 - 蓝紫灰色调
    MORT = (14, 12, 22, 255)    # 砖缝（极暗）
    BRK1 = (48, 42, 65, 255)   # 砖体 A
    BRK2 = (42, 36, 58, 255)   # 砖体 B
    BRK3 = (52, 46, 70, 255)   # 砖体 C 变化
    BHI  = (65, 56, 85, 255)   # 砖面高光
    BHI2 = (75, 65, 95, 255)   # 强高光
    BSH  = (28, 22, 38, 255)   # 砖底阴影
    BSHD = (18, 14, 28, 255)   # 深阴影
    TOP  = (78, 68, 100, 255)  # 顶部边缘高光

    for y in range(16):
        for x in range(16):
            img.putpixel((x, y), MORT)

    def brick(x0, y0, x1, y1, color):
        for yy in range(y0, y1+1):
            for xx in range(x0, x1+1):
                p(img, xx, yy, color)
        # 顶面高光（光从上方来）
        for xx in range(x0, x1+1):
            p(img, xx, y0, BHI)
        # 左面高光
        p(img, x0, y0, BHI2)
        p(img, x0, y0+1, BHI)
        # 底面阴影
        for xx in range(x0, x1+1):
            p(img, xx, y1, BSH)
        # 右面暗
        for yy in range(y0+1, y1+1):
            p(img, x1, yy, BSH)
        # 右下角最暗
        p(img, x1, y1, BSHD)

    # 三排错位砖块
    # 第一排
    brick(1,  1, 7,  4, BRK1)
    brick(9,  1, 14, 4, BRK2)
    # 第二排（错位半砖）
    brick(1,  6, 4,  9, BRK2)
    brick(6,  6, 11, 9, BRK3)
    brick(13, 6, 14, 9, BRK1)
    # 第三排
    brick(1, 11, 8, 14, BRK3)
    brick(10,11, 14,14, BRK1)

    # 砖面纹理 - 细微噪点
    import random
    random.seed(42)
    for _ in range(12):
        rx = random.randint(1, 14)
        ry = random.randint(1, 14)
        cur = img.getpixel((rx, ry))
        if cur[3] > 0 and cur != MORT:
            vary = random.choice([-6, -4, 4, 6])
            p(img, rx, ry, (
                max(0, min(255, cur[0]+vary)),
                max(0, min(255, cur[1]+vary)),
                max(0, min(255, cur[2]+vary+2)),
                255
            ))

    # 最顶部一条亮线（表示墙顶）
    for x in range(16):
        p(img, x, 0, TOP)

    # 最左侧暗线
    for y in range(16):
        p(img, 0, y, BSHD)

    return img

# ════════════════════════════════════════════════════════════
# PLAYER
# ════════════════════════════════════════════════════════════

def make_player_idle():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    # 颜色定义
    HLM  = (155, 165, 185, 255)  # 头盔银
    HLH  = (195, 205, 225, 255)  # 头盔高光
    HLD  = (95,  105, 125, 255)  # 头盔暗
    SKN  = (215, 182, 140, 255)  # 皮肤
    EYE  = (55,  175, 215, 255)  # 眼睛蓝
    ARM  = (80,  115, 165, 255)  # 盔甲蓝
    ARH  = (115, 152, 200, 255)  # 盔甲高光
    ARD  = (50,  75,  118, 255)  # 盔甲暗
    LEG  = (50,  62,  88,  255)  # 腿部暗
    LLG  = (72,  88,  118, 255)  # 腿部亮
    O    = (10,  8,   16,  255)  # 轮廓

    # 头盔顶
    for x in [5,6,7,8,9,10]: p(img, x, 0, HLM)
    p(img, 5, 0, HLH); p(img, 6, 0, HLH)
    p(img, 4, 0, O);   p(img, 11, 0, O)

    # 头盔侧
    for x in range(4, 12): p(img, x, 1, HLM)
    p(img, 4, 1, HLH); p(img, 5, 1, HLH)
    p(img, 3, 1, O);   p(img, 12, 1, O)

    # 面部开口（皮肤）
    p(img, 3, 2, HLD); p(img, 12, 2, HLD)
    for x in range(4, 12): p(img, x, 2, SKN)
    p(img, 3, 2, HLM); p(img, 12, 2, HLM)
    p(img, 2, 2, O);   p(img, 13, 2, O)

    # 眼睛
    p(img, 3, 3, HLM); p(img, 12, 3, HLM)
    for x in range(4, 12): p(img, x, 3, SKN)
    p(img, 5, 3, EYE); p(img, 6, 3, EYE)
    p(img, 9, 3, EYE); p(img, 10, 3, EYE)
    p(img, 2, 3, O);   p(img, 13, 3, O)

    # 下颌/面罩
    p(img, 3, 4, HLM); p(img, 12, 4, HLM)
    for x in range(4, 12): p(img, x, 4, HLD)
    p(img, 2, 4, O);   p(img, 13, 4, O)

    # 肩膀
    for x in range(2, 14): p(img, x, 5, ARH)
    p(img, 1, 5, O);   p(img, 14, 5, O)

    # 身体护甲
    for y in range(6, 9):
        p(img, 2, y, ARD); p(img, 3, y, ARM)
        for x in range(4, 12): p(img, x, y, ARM)
        p(img, 12, y, ARM); p(img, 13, y, ARD)
        p(img, 1, y, O);   p(img, 14, y, O)
    # 胸甲高光
    p(img, 5, 6, ARH); p(img, 6, 6, ARH); p(img, 7, 6, ARH)
    p(img, 8, 7, ARH)

    # 腰部
    for x in range(3, 13): p(img, x, 9, ARD)
    p(img, 2, 9, O);   p(img, 13, 9, O)

    # 腿部
    for y in range(10, 13):
        p(img, 4, y, O); p(img, 5, y, LLG); p(img, 6, y, LEG)
        p(img, 9, y, LEG); p(img, 10, y, LLG); p(img, 11, y, O)

    # 脚
    for x in [4,5,6]: p(img, x, 13, LLG); p(img, x, 14, O)
    for x in [9,10,11]: p(img, x, 13, LLG); p(img, x, 14, O)

    return img


def make_player_walk1():
    """左腿前迈"""
    img = make_player_idle()
    LEG = (50, 62, 88, 255)
    LLG = (72, 88, 118, 255)
    O   = (10, 8, 16, 255)
    # 清除原脚
    for y in range(10, 15):
        for x in [4,5,6,9,10,11]: p(img, x, y, (0,0,0,0))
    # 左腿前移
    for y in range(10, 14):
        p(img, 3, y, O); p(img, 4, y, LLG); p(img, 5, y, LEG)
    p(img, 3, 14, LLG); p(img, 4, 14, O)
    # 右腿后移
    for y in range(10, 13):
        p(img, 10, y, LEG); p(img, 11, y, LLG); p(img, 12, y, O)
    p(img, 10, 13, LLG); p(img, 11, 13, O)
    return img


def make_player_walk2():
    """右腿前迈"""
    img = make_player_idle()
    LEG = (50, 62, 88, 255)
    LLG = (72, 88, 118, 255)
    O   = (10, 8, 16, 255)
    for y in range(10, 15):
        for x in [4,5,6,9,10,11]: p(img, x, y, (0,0,0,0))
    # 右腿前移
    for y in range(10, 14):
        p(img, 10, y, LLG); p(img, 11, y, LEG); p(img, 12, y, O)
    p(img, 11, 14, LLG); p(img, 12, 14, O)
    # 左腿后移
    for y in range(10, 13):
        p(img, 3, y, O); p(img, 4, y, LEG); p(img, 5, y, LLG)
    p(img, 4, 13, LLG); p(img, 5, 13, O)
    return img


def make_player_attack():
    img = make_player_idle()
    # 向右挥剑
    SWD = (210, 225, 250, 255)
    SWH = (250, 252, 255, 255)
    GRD = (185, 148, 52, 255)
    HDL = (110, 65, 28, 255)
    O   = (10, 8, 16, 255)

    # 剑刃（斜向）
    coords_blade = [(14,1),(13,2),(14,2),(12,3),(13,3),(11,4),(12,4),(15,1),(15,2)]
    for (x,y) in coords_blade: p(img, x, y, SWD)
    p(img, 14, 1, SWH); p(img, 13, 2, SWH)
    p(img, 15, 0, SWH)

    # 护手
    for x in [13,14,15]: p(img, x, 5, GRD)
    p(img, 12, 5, O); p(img, 15, 4, O); p(img, 15, 6, O)

    # 剑柄
    p(img, 14, 6, HDL); p(img, 14, 7, HDL)
    p(img, 13, 6, O); p(img, 15, 6, O)

    return img

# ════════════════════════════════════════════════════════════
# ENEMIES
# ════════════════════════════════════════════════════════════

def make_slime():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    O   = (10, 35, 10, 255)
    GD  = (28, 130, 28, 255)   # 暗绿
    GM  = (55, 185, 55, 255)   # 中绿
    GL  = (95, 225, 95, 255)   # 亮绿
    GH  = (155, 255, 155, 255) # 高光
    EW  = (238, 238, 238, 255) # 眼白
    EB  = (18, 18, 28, 255)    # 眼黑
    GLP = (40, 200, 40, 120)   # 发光

    # 外发光
    for x in range(1, 15):
        for y in range(3, 13):
            dx = (x - 7.5); dy = (y - 8.5)
            if dx*dx/36 + dy*dy/25 < 1.5:
                p(img, x, y, GLP)

    # 主体轮廓（水滴形）
    body = [
        (4,4),(5,4),(6,4),(7,4),(8,4),(9,4),(10,4),(11,4),
        (3,5),(4,5),(5,5),(6,5),(7,5),(8,5),(9,5),(10,5),(11,5),(12,5),
        (2,6),(3,6),(4,6),(5,6),(6,6),(7,6),(8,6),(9,6),(10,6),(11,6),(12,6),(13,6),
        (2,7),(3,7),(4,7),(5,7),(6,7),(7,7),(8,7),(9,7),(10,7),(11,7),(12,7),(13,7),
        (2,8),(3,8),(4,8),(5,8),(6,8),(7,8),(8,8),(9,8),(10,8),(11,8),(12,8),(13,8),
        (3,9),(4,9),(5,9),(6,9),(7,9),(8,9),(9,9),(10,9),(11,9),(12,9),
        (4,10),(5,10),(6,10),(7,10),(8,10),(9,10),(10,10),(11,10),
        (5,11),(6,11),(8,11),(9,11),(11,11),
    ]
    for (x,y) in body: p(img, x, y, GM)

    # 底部阴影
    for (x,y) in body:
        if y >= 9: p(img, x, y, GD)

    # 顶部高光
    hi = [(6,5),(7,5),(8,5),(6,6),(7,6),(5,6)]
    for (x,y) in hi: p(img, x, y, GL)
    p(img, 7, 5, GH); p(img, 6, 5, GH)

    # 眼睛
    p(img, 6, 7, EW); p(img, 7, 7, EW); p(img, 9, 7, EW); p(img, 10, 7, EW)
    p(img, 6, 8, EB); p(img, 7, 8, EW); p(img, 9, 8, EB); p(img, 10, 8, EW)

    # 轮廓
    outline_pts = [(3,4),(12,4),(2,5),(13,5),(1,6),(14,6),(1,7),(14,7),
                   (1,8),(14,8),(2,9),(13,9),(3,10),(12,10),(4,11),(11,11),
                   (5,12),(6,12),(7,12),(8,12),(9,12),(10,12),(4,4),(11,4)]
    for (x,y) in outline_pts: p(img, x, y, O)

    return img


def make_skeleton():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    O   = (18, 14, 10, 255)
    BN  = (215, 205, 178, 255)  # 骨骼
    BH  = (242, 236, 215, 255)  # 高光
    BD  = (155, 145, 122, 255)  # 暗
    EG  = (80, 210, 80, 255)    # 绿色眼睛发光
    ES  = (12, 12, 18, 255)     # 眼眶黑

    # 头骨
    for x in range(5, 11): p(img, x, 1, BN)
    for x in range(4, 12): p(img, x, 2, BN)
    for x in range(4, 12): p(img, x, 3, BN)
    for x in range(5, 11): p(img, x, 4, BN)
    # 头骨高光
    p(img, 5, 2, BH); p(img, 6, 2, BH); p(img, 7, 2, BH)
    # 眼眶
    p(img, 5, 3, ES); p(img, 6, 3, EG)
    p(img, 9, 3, ES); p(img, 10, 3, EG)
    # 下颌锯齿
    for x in range(5, 11): p(img, x, 5, BN)
    p(img, 5, 5, BD); p(img, 7, 5, BD); p(img, 9, 5, BD)
    p(img, 6, 5, BH); p(img, 8, 5, BH); p(img, 10, 5, BH)

    # 脊椎
    p(img, 7, 6, BN); p(img, 8, 6, BN)
    p(img, 7, 7, BD); p(img, 8, 7, BD)

    # 肋骨
    for x in range(5, 11): p(img, x, 8, BD)
    for y in range(8, 12):
        p(img, 5, y, BN); p(img, 10, y, BN)
    p(img, 6, 9, BN); p(img, 9, 9, BN)
    p(img, 6, 10, BD); p(img, 9, 10, BD)
    p(img, 7, 9, BH); p(img, 8, 9, BH)

    # 骨盆
    for x in range(5, 11): p(img, x, 12, BD)

    # 腿骨
    for y in range(13, 16):
        p(img, 5, y, BN); p(img, 6, y, BN)
        p(img, 9, y, BN); p(img, 10, y, BN)
    p(img, 5, 15, BD); p(img, 10, 15, BD)

    # 轮廓
    add_outline(img, O)
    return img


def make_boss():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    O   = (4, 3, 8, 255)
    ADK = (22, 12, 38, 255)   # 极暗紫甲
    AMD = (44, 28, 68, 255)   # 中紫甲
    AHI = (80, 52, 118, 255)  # 甲高光
    ER  = (255, 38, 18, 255)  # 红眼
    ERG = (180, 18, 8, 200)   # 红眼光晕
    CPE = (60, 8, 20, 255)    # 深红披风
    CPD = (35, 4, 12, 255)    # 披风暗
    SIL = (100, 68, 140, 200) # 外发光

    # 外光晕
    for x in range(1, 15):
        for y in range(0, 15):
            dx = (x-7.5); dy = (y-7)
            if dx*dx/40 + dy*dy/52 < 1.2:
                cur = img.getpixel((x,y))
                if cur[3] == 0: p(img, x, y, SIL)

    # 披风（身后）
    for y in range(4, 15):
        p(img, 2, y, CPD); p(img, 13, y, CPD)
    for y in range(5, 14):
        p(img, 3, y, CPE); p(img, 12, y, CPE)

    # 头盔角
    p(img, 3, 0, AHI); p(img, 4, 0, AMD)
    p(img, 11, 0, AMD); p(img, 12, 0, AHI)

    # 头盔
    for x in range(4, 12): p(img, x, 0, AMD)
    for x in range(4, 12): p(img, x, 1, AMD)
    p(img, 4, 0, AHI); p(img, 5, 0, AHI); p(img, 6, 0, AHI)
    p(img, 4, 1, AHI)

    # 面罩（红眼）
    for x in range(4, 12): p(img, x, 2, ADK)
    p(img, 5, 2, ERG); p(img, 6, 2, ER); p(img, 7, 2, ERG)
    p(img, 9, 2, ERG); p(img, 10, 2, ER); p(img, 11, 2, ERG)

    # 护颈
    for x in range(5, 11): p(img, x, 3, AMD)

    # 宽肩
    for x in range(2, 14): p(img, x, 4, AHI)
    p(img, 1, 4, AMD); p(img, 14, 4, AMD)

    # 身体（更宽更壮）
    for y in range(5, 9):
        p(img, 2, y, AMD); p(img, 3, y, ADK)
        for x in range(4, 12): p(img, x, y, AMD)
        p(img, 12, y, ADK); p(img, 13, y, AMD)
    # 胸甲细节
    p(img, 6, 5, AHI); p(img, 7, 5, AHI); p(img, 8, 5, AHI)
    p(img, 7, 6, AHI); p(img, 7, 7, AHI)

    # 腰部
    for x in range(3, 13): p(img, x, 9, ADK)

    # 腿甲（更粗）
    for y in range(10, 14):
        p(img, 3, y, ADK); p(img, 4, y, AMD); p(img, 5, y, AMD)
        p(img, 10, y, AMD); p(img, 11, y, AMD); p(img, 12, y, ADK)

    # 靴子
    for x in range(3, 7): p(img, x, 14, AMD)
    for x in range(9, 14): p(img, x, 14, AMD)

    add_outline(img, O)
    return img

# ════════════════════════════════════════════════════════════
# ITEMS
# ════════════════════════════════════════════════════════════

def make_loot():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    O   = (18, 8, 38, 255)
    GD  = (75, 18, 155, 255)   # 暗宝石
    GM  = (135, 55, 218, 255)  # 中宝石
    GL  = (175, 108, 255, 255) # 亮宝石
    GH  = (228, 195, 255, 255) # 高光
    GLW = (180, 120, 255, 80)  # 发光

    # 发光光晕
    for x in range(16):
        for y in range(16):
            dx = x-7.5; dy = y-7.5
            if dx*dx + dy*dy < 38:
                p(img, x, y, GLW)

    # 宝石顶端
    p(img, 7, 3, GD); p(img, 8, 3, GD)
    # 上部
    for x in range(5, 11): p(img, x, 4, GM)
    for x in range(4, 12): p(img, x, 5, GM)
    # 中部（最宽）
    for x in range(4, 12): p(img, x, 6, GL)
    for x in range(4, 12): p(img, x, 7, GL)
    # 下部
    for x in range(5, 11): p(img, x, 8, GM)
    for x in range(6, 10): p(img, x, 9, GM)
    # 底尖
    p(img, 7, 10, GD); p(img, 8, 10, GD)
    p(img, 7, 11, GD)

    # 高光
    p(img, 6, 4, GH); p(img, 7, 4, GH)
    p(img, 5, 5, GH); p(img, 6, 5, GH)
    p(img, 5, 6, GH); p(img, 6, 6, GH)

    # 宝石反光（右下）
    p(img, 10, 7, GL); p(img, 11, 7, GM)
    p(img, 10, 8, GM)

    # 轮廓
    outline_pts = [
        (7,2),(8,2),(4,3),(5,3),(6,3),(9,3),(10,3),(11,3),
        (3,4),(12,4),(3,5),(12,5),(3,6),(12,6),(3,7),(12,7),
        (4,8),(11,8),(5,9),(10,9),(6,10),(9,10),(7,11),(8,11),(7,12)
    ]
    for (x,y) in outline_pts: p(img, x, y, O)
    return img


def make_sword_icon():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    O   = (8, 6, 12, 255)
    BH  = (245, 250, 255, 255)  # 刃高光
    BM  = (195, 210, 235, 255)  # 刃中
    BD  = (130, 148, 175, 255)  # 刃暗
    GRD = (195, 155, 48, 255)   # 护手金
    HDL = (115, 65, 25, 255)    # 剑柄

    # 刃（对角线）
    pairs = [(13,1),(12,2),(11,3),(10,4),(9,5),(8,6),(7,7)]
    for i, (x,y) in enumerate(pairs):
        p(img, x, y, BH if i < 2 else BM)
        p(img, x-1, y, BD)
    p(img, 14, 0, BH); p(img, 15, 0, O)
    p(img, 14, 1, BM); p(img, 15, 1, O)

    # 护手
    p(img, 6, 7, GRD); p(img, 7, 8, GRD); p(img, 8, 8, GRD); p(img, 6, 8, GRD)
    p(img, 5, 7, O); p(img, 9, 8, O); p(img, 5, 8, O); p(img, 5, 9, O)

    # 剑柄
    for i, (x,y) in enumerate([(6,9),(5,10),(4,11),(3,12)]):
        p(img, x, y, HDL)
    # 剑柄轮廓
    for (x,y) in [(7,9),(5,9),(4,10),(6,10),(3,11),(5,11),(2,12),(4,12)]:
        p(img, x, y, O)

    # 剑柄末端
    p(img, 2, 13, GRD); p(img, 3, 13, GRD)
    p(img, 1, 12, O); p(img, 1, 13, O); p(img, 4, 13, O); p(img, 2, 14, O); p(img, 3, 14, O)

    return img


def make_hit_effect():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    # 十字星爆炸效果
    colors = [
        (255, 255, 200, 255), (255, 220, 100, 200),
        (255, 160, 60, 150),  (255, 100, 30, 80)
    ]
    cx, cy = 7, 7
    for i, c in enumerate(colors):
        r = i * 1.5 + 1
        # 4个方向
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            x = int(cx + math.cos(rad) * r)
            y = int(cy + math.sin(rad) * r)
            p(img, x, y, c)
    p(img, cx, cy, (255, 255, 255, 255))
    return img


# ════════════════════════════════════════════════════════════
# 主函数（只在直接运行时执行，import 时不触发）
# ════════════════════════════════════════════════════════════

def make_torch():
    """生成火把精灵表 — 4 帧横排 (每帧 16x16)"""
    frames = 4
    img = Image.new("RGBA", (16 * frames, 16), (0, 0, 0, 0))

    HANDLE  = (70, 50, 35, 255)
    HANDLE2 = (55, 38, 25, 255)
    BRACKET = (100, 90, 70, 255)

    FLAME_CORE   = (255, 240, 180, 255)
    FLAME_MID    = (255, 160, 40, 255)
    FLAME_OUTER  = (220, 90, 15, 255)
    FLAME_TIP    = (255, 200, 80, 200)
    EMBER        = (180, 60, 10, 180)

    import random
    random.seed(42)

    for f in range(frames):
        ox = f * 16

        for y in range(9, 15):
            p(img, ox + 7, y, HANDLE)
            p(img, ox + 8, y, HANDLE2)

        p(img, ox + 6, 9, BRACKET)
        p(img, ox + 9, 9, BRACKET)
        p(img, ox + 6, 8, BRACKET)
        p(img, ox + 9, 8, BRACKET)
        p(img, ox + 15, 15, (0, 0, 0, 0))

        flame_shift = [0, 1, 0, -1][f]

        p(img, ox + 7, 7, FLAME_OUTER)
        p(img, ox + 8, 7, FLAME_OUTER)
        p(img, ox + 6, 6 + flame_shift, FLAME_OUTER)
        p(img, ox + 9, 6 + flame_shift, FLAME_OUTER)

        p(img, ox + 7, 5 + flame_shift, FLAME_MID)
        p(img, ox + 8, 5 + flame_shift, FLAME_MID)
        p(img, ox + 7, 6, FLAME_MID)
        p(img, ox + 8, 6, FLAME_MID)

        p(img, ox + 7, 4 + flame_shift, FLAME_CORE)
        p(img, ox + 8, 4 + flame_shift, FLAME_CORE)

        tip_x = 7 + [0, 1, 0, -1][f]
        p(img, ox + tip_x, 3 + flame_shift, FLAME_TIP)

        if f % 2 == 0:
            p(img, ox + 5, 5 + flame_shift, EMBER)
        else:
            p(img, ox + 10, 4 + flame_shift, EMBER)

    return img


if __name__ == "__main__":
    print("正在生成像素美术精灵（地板、墙壁、虚空和火把）...")

    sprites = [
        (make_floor(),  f"{BASE}/tiles/floor.png"),
        (make_wall(),   f"{BASE}/tiles/wall.png"),
        (make_void(),   f"{BASE}/tiles/void.png"),
        (make_torch(),  f"{BASE}/objects/torch.png"),
    ]

    for img, path in sprites:
        save(img, path)

    print(f"\n完成！共生成 {len(sprites)} 个精灵。")
