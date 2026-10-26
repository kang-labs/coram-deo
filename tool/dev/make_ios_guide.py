"""아이폰 '홈 화면에 추가' 안내 그림 한 장 (사파리 → 공유 → 홈 화면에 추가(웹 앱으로 열기 켜기) → 아이콘으로 열기).

사용: python tool/dev/make_ios_guide.py [출력 폴더]   (저장소 루트에서, Pillow 필요)
출력 폴더를 안 주면 ../../../Release/Bible/coram_deo/guide 에 만든다.
아이폰 화면은 실제 캡처가 아니라 단순하게 그린 그림이다. 앱 아이콘은 make_icons.py 그림을 쓴다.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from make_icons import CROSS, NAVY, render  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, '..', '..', '..', 'Release', 'Bible', 'coram_deo', 'guide')
FONTS = os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts')
URL = 'coram-deo-biblekang.web.app'

# 색 (앱 테마와 같은 남색 + 강조는 주황 테두리)
BG = (0xF6, 0xF7, 0xF9)
INK = (0x1F, 0x2A, 0x40)
SOFT = (0x5E, 0x6B, 0x80)
LINE = (0xDC, 0xE2, 0xEC)
BEZEL = (0x1F, 0x2A, 0x40)
WHITE = (0xFF, 0xFF, 0xFF)
GREY = (0xEE, 0xEF, 0xF3)
MID = (0xC7, 0xCC, 0xD6)
BLUE = (0x0A, 0x84, 0xFF)  # iOS 기본 파란 글자
GREEN = (0x34, 0xC7, 0x59)  # iOS 스위치 켜짐
MARK = (0xF2, 0x9A, 0x2E)  # 누를 곳 표시

W = 1080
PHONE_W, PHONE_H = 440, 880
SCREEN_PAD = 14
COLS_X = (70, W - 70 - PHONE_W)


def font(bold, size):
    return ImageFont.truetype(os.path.join(FONTS, 'malgunbd.ttf' if bold else 'malgun.ttf'), size)


def ring(d, box, r=18):
    """누를 곳 주황 테두리"""
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0 - 8, y0 - 8, x1 + 8, y1 + 8], radius=r, outline=MARK, width=6)


def app_icon(size, rounded=True):
    return render(bg='round' if rounded else 'square').resize((size, size), Image.LANCZOS)


def share_glyph(d, cx, cy, s, color):
    """공유 버튼 □↑"""
    d.rounded_rectangle([cx - s, cy - s * 0.2, cx + s, cy + s * 1.2], radius=s * 0.25, outline=color, width=3)
    d.rectangle([cx - s * 0.35, cy - s * 0.4, cx + s * 0.35, cy + s * 0.1], fill=WHITE)
    d.line([cx, cy - s * 1.1, cx, cy + s * 0.5], fill=color, width=3)
    d.line([cx - s * 0.45, cy - s * 0.65, cx, cy - s * 1.1, cx + s * 0.45, cy - s * 0.65], fill=color, width=3)


def phone(img, x, y):
    """폰 테두리를 그리고 화면 영역(x0, y0, x1, y1)을 돌려줘요"""
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x, y, x + PHONE_W, y + PHONE_H], radius=60, fill=BEZEL)
    sx0, sy0, sx1, sy1 = x + SCREEN_PAD, y + SCREEN_PAD, x + PHONE_W - SCREEN_PAD, y + PHONE_H - SCREEN_PAD
    d.rounded_rectangle([sx0, sy0, sx1, sy1], radius=48, fill=WHITE)
    return sx0, sy0, sx1, sy1


def status_bar(d, sx0, sy0, sx1, color=INK):
    d.text((sx0 + 40, sy0 + 18), '9:41', font=font(True, 20), fill=color)
    d.rounded_rectangle([(sx0 + sx1) / 2 - 55, sy0 + 14, (sx0 + sx1) / 2 + 55, sy0 + 44], radius=15, fill=BEZEL)


def page(d, sx0, sy0, sx1, sy1):
    """사파리에 열린 앱 화면 (단순하게)"""
    d.rectangle([sx0, sy0 + 60, sx1, sy0 + 140], fill=NAVY[:3])
    d.text((sx0 + 28, sy0 + 82), '하나님앞에서', font=font(True, 28), fill=CROSS[:3])
    y = sy0 + 165
    for h in (130, 100, 100, 100):
        d.rounded_rectangle([sx0 + 22, y, sx1 - 22, y + h], radius=18, fill=GREY)
        d.rounded_rectangle([sx0 + 44, y + 22, sx0 + 200, y + 40], radius=8, fill=MID)
        y += h + 16


def safari_bar(d, sx0, sy0, sx1, sy1):
    """아래쪽 사파리 주소창: ‹  [주소]  ⋯ . ⋯ 버튼 자리를 돌려줘요"""
    by = sy1 - 120
    d.rectangle([sx0, by - 10, sx1, sy1], fill=(0xF9, 0xF9, 0xFB))
    d.ellipse([sx0 + 18, by, sx0 + 78, by + 60], fill=GREY)
    d.text((sx0 + 38, by + 6), '‹', font=font(True, 36), fill=INK)
    d.rounded_rectangle([sx0 + 90, by, sx1 - 90, by + 60], radius=30, fill=GREY)
    d.text(((sx0 + sx1) / 2, by + 30), URL, font=font(False, 17), fill=INK, anchor='mm')
    dots = (sx1 - 78, by, sx1 - 18, by + 60)
    d.ellipse(dots, fill=GREY)
    d.text(((dots[0] + dots[2]) / 2, by + 26), '···', font=font(True, 26), fill=INK, anchor='mm')
    return dots


def step1(img, x, y):
    sx0, sy0, sx1, sy1 = phone(img, x, y)
    d = ImageDraw.Draw(img)
    status_bar(d, sx0, sy0, sx1)
    page(d, sx0, sy0, sx1, sy1)
    dots = safari_bar(d, sx0, sy0, sx1, sy1)
    # ⋯ 메뉴에서 '공유'
    mx0, my1 = sx1 - 250, dots[1] - 24
    d.rounded_rectangle([mx0, my1 - 190, sx1 - 18, my1], radius=22, fill=WHITE, outline=LINE, width=2)
    rows = ['공유', '책갈피 추가', '페이지에서 찾기']
    for i, label in enumerate(rows):
        ry = my1 - 190 + i * 63
        if i:
            d.line([mx0 + 16, ry, sx1 - 34, ry], fill=LINE, width=2)
        d.text((mx0 + 22, ry + 31), label, font=font(i == 0, 21), fill=INK, anchor='lm')
        if i == 0:
            share_glyph(d, sx1 - 56, ry + 28, 11, INK)
            ring(d, (mx0 + 4, ry + 4, sx1 - 22, ry + 58), r=16)
    ring(d, dots, r=34)


def step2(img, x, y):
    sx0, sy0, sx1, sy1 = phone(img, x, y)
    d = ImageDraw.Draw(img)
    status_bar(d, sx0, sy0, sx1)
    page(d, sx0, sy0, sx1, sy1)
    # 어둡게 + 공유 시트
    shade = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).rounded_rectangle([sx0, sy0, sx1, sy1], radius=48, fill=(0, 0, 0, 90))
    img.alpha_composite(shade)
    d = ImageDraw.Draw(img)
    top = sy0 + 250
    d.rounded_rectangle([sx0, top, sx1, sy1], radius=40, fill=(0xF2, 0xF2, 0xF7))
    d.rectangle([sx0, sy1 - 60, sx1, sy1 - 48], fill=(0xF2, 0xF2, 0xF7))
    img.alpha_composite(app_icon(64), (sx0 + 26, top + 28))
    d.text((sx0 + 106, top + 34), '하나님앞에서', font=font(True, 20), fill=INK)
    d.text((sx0 + 106, top + 62), URL, font=font(False, 15), fill=SOFT)
    # 앱 줄 (에어드롭·메시지·메일)
    for i, label in enumerate(['AirDrop', '메시지', '메일', '메모']):
        cx = sx0 + 62 + i * 98
        d.ellipse([cx - 32, top + 120, cx + 32, top + 184], fill=MID)
        d.text((cx, top + 204), label, font=font(False, 14), fill=SOFT, anchor='mm')
    # 목록
    ly = top + 240
    rows = ['복사', '읽기 목록에 추가', '홈 화면에 추가', '페이지에서 찾기']
    d.rounded_rectangle([sx0 + 18, ly, sx1 - 18, ly + 4 * 62], radius=18, fill=WHITE)
    for i, label in enumerate(rows):
        ry = ly + i * 62
        if i:
            d.line([sx0 + 34, ry, sx1 - 34, ry], fill=LINE, width=2)
        d.text((sx0 + 38, ry + 31), label, font=font(i == 2, 21), fill=INK, anchor='lm')
        if i == 2:
            # ⊞ 아이콘
            bx = sx1 - 64
            d.rounded_rectangle([bx - 14, ry + 17, bx + 14, ry + 45], radius=6, outline=INK, width=3)
            d.line([bx, ry + 23, bx, ry + 39], fill=INK, width=3)
            d.line([bx - 8, ry + 31, bx + 8, ry + 31], fill=INK, width=3)
            ring(d, (sx0 + 18, ry + 2, sx1 - 18, ry + 60), r=16)


def step3(img, x, y):
    sx0, sy0, sx1, sy1 = phone(img, x, y)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([sx0, sy0, sx1, sy1], radius=48, fill=(0xF2, 0xF2, 0xF7))
    status_bar(d, sx0, sy0, sx1)
    ny = sy0 + 100
    d.text((sx0 + 26, ny), '취소', font=font(False, 22), fill=BLUE, anchor='lm')
    d.text(((sx0 + sx1) / 2, ny), '홈 화면에 추가', font=font(True, 22), fill=INK, anchor='mm')
    add = (sx1 - 82, ny - 22, sx1 - 24, ny + 22)
    d.text((sx1 - 26, ny), '추가', font=font(True, 22), fill=BLUE, anchor='rm')
    # 아이콘·이름 칸
    cy = ny + 50
    d.rounded_rectangle([sx0 + 18, cy, sx1 - 18, cy + 150], radius=18, fill=WHITE)
    img.alpha_composite(app_icon(104), (sx0 + 36, cy + 23))
    d.text((sx0 + 160, cy + 40), '하나님앞에서', font=font(False, 22), fill=INK)
    d.line([sx0 + 160, cy + 78, sx1 - 34, cy + 78], fill=LINE, width=2)
    d.text((sx0 + 160, cy + 94), URL, font=font(False, 15), fill=SOFT)
    # 웹 앱으로 열기 스위치
    ty = cy + 180
    d.rounded_rectangle([sx0 + 18, ty, sx1 - 18, ty + 70], radius=18, fill=WHITE)
    d.text((sx0 + 38, ty + 35), '웹 앱으로 열기', font=font(True, 21), fill=INK, anchor='lm')
    tx1 = sx1 - 38
    d.rounded_rectangle([tx1 - 70, ty + 15, tx1, ty + 55], radius=20, fill=GREEN)
    d.ellipse([tx1 - 38, ty + 18, tx1 - 4, ty + 52], fill=WHITE)
    ring(d, (sx0 + 18, ty, sx1 - 18, ty + 70), r=20)
    d.multiline_text(
        (sx0 + 34, ty + 90),
        '꼭 켜(초록색) 두세요.\n켜야 사파리 탭이 아닌 앱처럼 열려요.',
        font=font(False, 17),
        fill=SOFT,
        spacing=6,
    )
    ring(d, add, r=14)


def step4(img, x, y):
    sx0, sy0, sx1, sy1 = phone(img, x, y)
    d = ImageDraw.Draw(img)
    # 바탕화면
    wall = Image.new('RGBA', (sx1 - sx0, sy1 - sy0))
    wd = ImageDraw.Draw(wall)
    for i in range(sy1 - sy0):
        t = i / (sy1 - sy0)
        wd.line([0, i, sx1 - sx0, i], fill=(int(0x6B + (0x2F - 0x6B) * t), int(0x86 + (0x3E - 0x86) * t), int(0xA6 + (0x5C - 0xA6) * t), 255))
    mask = Image.new('L', wall.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, wall.width - 1, wall.height - 1], radius=48, fill=255)
    img.paste(wall, (sx0, sy0), mask)
    d = ImageDraw.Draw(img)
    status_bar(d, sx0, sy0, sx1, color=WHITE)
    size, gap_x = 76, (sx1 - sx0 - 4 * 76) / 5
    for r in range(5):
        for c in range(4):
            ix = sx0 + gap_x + c * (size + gap_x)
            iy = sy0 + 90 + r * 128
            if (r, c) == (2, 1):
                img.alpha_composite(app_icon(size), (int(ix), int(iy)))
                d.text((ix + size / 2, iy + size + 16), '하나님앞에서', font=font(True, 15), fill=WHITE, anchor='mm')
                ring(d, (ix - 6, iy - 6, ix + size + 6, iy + size + 30), r=22)
            else:
                d.rounded_rectangle([ix, iy, ix + size, iy + size], radius=18, fill=(255, 255, 255, 255) if False else (0xD5, 0xDD, 0xEA))
                d.rounded_rectangle([ix + 18, iy + size + 12, ix + size - 18, iy + size + 20], radius=4, fill=(0xD5, 0xDD, 0xEA))
    # 독
    dy = sy1 - 130
    d.rounded_rectangle([sx0 + 20, dy, sx1 - 20, dy + 106], radius=36, fill=(0xA5, 0xB0, 0xC2))
    for c in range(4):
        ix = sx0 + gap_x + c * (size + gap_x)
        d.rounded_rectangle([ix, dy + 15, ix + size, dy + 15 + size], radius=18, fill=(0xE8, 0xEC, 0xF3))


STEPS = [
    (step1, '주소창 옆 ··· → 공유', '공유 버튼 {share} 이 보이면 바로 눌러요'),
    (step2, '“홈 화면에 추가” 누르기', '안 보이면 목록을 위로 올려요'),
    (step3, '“웹 앱으로 열기” 켜고 “추가”', '켜져 있으면 그대로 “추가”'),
    (step4, '홈 화면 아이콘으로 열기', '반은 처음 한 번 다시 골라요'),
]


def main():
    title_h, cap_h, note_h = 250, 170, 250
    h = title_h + 2 * (PHONE_H + cap_h) + note_h
    img = Image.new('RGBA', (W, h), BG + (255,))
    d = ImageDraw.Draw(img)
    img.alpha_composite(app_icon(110), (70, 70))
    d.text((205, 78), '아이폰 홈 화면에 추가하기', font=font(True, 52), fill=INK)
    d.text((207, 150), '하나님앞에서 · 사파리에서 한 번만 해 두면 돼요', font=font(False, 28), fill=SOFT)
    for i, (draw, cap, sub) in enumerate(STEPS):
        col, row = i % 2, i // 2
        x = COLS_X[col]
        y = title_h + row * (PHONE_H + cap_h)
        draw(img, x, y)
        d = ImageDraw.Draw(img)
        cy = y + PHONE_H + 28
        d.ellipse([x, cy, x + 52, cy + 52], fill=NAVY)
        d.text((x + 26, cy + 25), str(i + 1), font=font(True, 30), fill=CROSS, anchor='mm')
        d.text((x + 66, cy + 26), cap, font=font(True, 26), fill=INK, anchor='lm')
        if sub:
            # {share}는 글자 대신 공유 아이콘을 그려요(글꼴에 따라 □↑ 기호가 깨져 보여서)
            f, tx = font(False, 20), x + 66
            for k, part in enumerate(sub.split('{share}')):
                if k:
                    share_glyph(d, tx + 14, cy + 70, 9, SOFT)
                    tx += 28
                d.text((tx, cy + 72), part, font=f, fill=SOFT, anchor='lm')
                tx += d.textlength(part, font=f)
    ny = title_h + 2 * (PHONE_H + cap_h) + 10
    d.rounded_rectangle([70, ny, W - 70, ny + 200], radius=24, fill=WHITE, outline=LINE, width=2)
    d.multiline_text(
        (100, ny + 30),
        '• 카카오톡 안에서 열렸다면 오른쪽 아래 ··· → “Safari로 열기”부터 해요.\n'
        '• 사파리 탭에서 계속 쓰면 기록이 지워질 수 있어요.\n'
        '  꼭 홈 화면 아이콘으로 열어 주세요.\n'
        '• 주소: ' + URL,
        font=font(False, 25),
        fill=INK,
        spacing=12,
    )
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'iphone-home-screen-guide.png')
    img.convert('RGB').save(path, optimize=True)
    print('안내 그림을 만들었어요:', os.path.abspath(path))


if __name__ == '__main__':
    main()
