"""앱 아이콘 생성: 남색 바탕, 회청색 언덕 위 흰 십자가.

사용: python tool/dev/make_icons.py   (저장소 루트에서, Pillow 필요)
안드로이드 mipmap-*·웹 web/icons·favicon을 한 번에 다시 만든다.
디자인 좌표는 120x120 기준.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
WEB = os.path.join(ROOT, 'web')

NAVY = (0x2F, 0x3E, 0x5C, 255)
HILL = (0x5E, 0x7A, 0x99, 255)
CROSS = (0xF6, 0xF7, 0xF9, 255)

# 120 기준 도형
CROSS_BARS = [(56, 22, 9, 50), (44, 34, 33, 9)]  # x, y, w, h
CROSS_R = 1.5  # 십자가 모서리 둥글기
# 언덕: M0 94 C30 70 90 70 120 94 L120 120 L0 120 Z
HILL_CURVE = [(0, 94), (30, 70), (90, 70), (120, 94)]

S = 2048  # 크게 그린 뒤 줄임


def _bezier(p, n=200):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = p
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u ** 3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t ** 3 * x3,
                    u ** 3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t ** 3 * y3))
    return pts


def render(scale=1.0, bg='square', hill=True, cross=True):
    """S 크기 그림. scale<1이면 가운데 기준으로 도형을 줄인다(안전 영역용).
    bg: 'square' | 'round' | None(투명). 언덕은 줄여도 좌우·아래 가장자리까지 채운다."""
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = S / 120

    def tx(x, y):  # 120 좌표 → 캔버스 좌표 (가운데 기준 축소)
        return ((60 + (x - 60) * scale) * u, (60 + (y - 60) * scale) * u)

    if bg == 'square':
        d.rectangle([0, 0, S, S], fill=NAVY)
    elif bg == 'round':
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=NAVY)

    if cross:
        for i, (x, y, w, h) in enumerate(CROSS_BARS):
            (x0, y0), (x1, y1) = tx(x, y), tx(x + w, y + h)
            if i == 0 and hill:  # 세로 막대 아래쪽은 언덕 속으로 묻는다
                y1 = S
            d.rounded_rectangle([x0, y0, x1, y1], radius=CROSS_R * scale * u, fill=CROSS)

    if hill:
        curve = [tx(x, y) for x, y in _bezier(HILL_CURVE)]
        # 줄였을 때는 곡선 양 끝의 접선 방향으로 가장자리까지 잇는다(꺾임 없이)
        (ax, ay), (bx, by) = curve[0], curve[1]
        left = (0, ay + (ay - by) / (bx - ax) * ax)
        (ax, ay), (bx, by) = curve[-1], curve[-2]
        right = (S, ay + (ay - by) / (ax - bx) * (S - ax))
        poly = [left] + curve + [right, (S, S), (0, S)]
        d.polygon(poly, fill=HILL)

    if bg == 'round':  # 언덕이 둥근 모서리 밖으로 나가지 않게
        mask = Image.new('L', (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=255)
        img.putalpha(Image.composite(img.getchannel('A'), mask, mask))
    return img


def save(img, path, px):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((px, px), Image.LANCZOS).save(path, optimize=True)


def main():
    rounded = render(bg='round')
    full = render(bg='square')
    # 웹 maskable: 안전 영역은 지름 80% 원 → 0.8배
    maskable = render(scale=0.8, bg='square')
    # 안드로이드 적응형: 108dp 중 보이는 72dp에 원래 디자인이 오게 72/108배
    k = 72 / 108
    fore = render(scale=k, bg=None)
    mono = render(scale=k, bg=None, hill=False)  # 테마 아이콘: 십자가만

    dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for dn, m in dens.items():
        folder = os.path.join(RES, f'mipmap-{dn}')
        save(rounded, os.path.join(folder, 'ic_launcher.png'), int(48 * m))
        save(fore, os.path.join(folder, 'ic_launcher_foreground.png'), int(108 * m))
        save(mono, os.path.join(folder, 'ic_launcher_monochrome.png'), int(108 * m))

    icons = os.path.join(WEB, 'icons')
    for px in (192, 512):
        save(rounded, os.path.join(icons, f'Icon-{px}.png'), px)
        save(maskable, os.path.join(icons, f'Icon-maskable-{px}.png'), px)
    save(full, os.path.join(icons, 'apple-touch-icon.png'), 180)
    save(rounded, os.path.join(WEB, 'favicon.png'), 32)
    print('아이콘을 만들었어요.')


if __name__ == '__main__':
    main()
