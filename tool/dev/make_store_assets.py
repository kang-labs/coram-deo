"""Play 스토어 등록정보 그림: 앱 아이콘 512x512, 그래픽 이미지 1024x500.

사용: python tool/dev/make_store_assets.py [출력 폴더]   (저장소 루트에서, Pillow 필요)
출력 폴더를 안 주면 ../../../Release/Bible/coram_deo/store 에 만든다.
아이콘 모양은 make_icons.py와 같은 그림을 쓴다(색·도형을 한곳에서).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from make_icons import CROSS, render  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, '..', '..', '..', 'Release', 'Bible', 'coram_deo', 'store')
FONTS = os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts')
SOFT = (0xD5, 0xDD, 0xEA, 255)
BG = (0x45, 0x59, 0x7F, 255)  # 아이콘(남색 타일)이 도드라지게 조금 밝은 남색
FAR_HILL = (0x6B, 0x86, 0xA6, 255)


def font(bold, size):
    return ImageFont.truetype(os.path.join(FONTS, 'malgunbd.ttf' if bold else 'malgun.ttf'), size)


def icon():
    # Play가 둥글게 잘라 쓰므로 모서리까지 꽉 찬 정사각형으로 준다
    return render(bg='square').resize((512, 512), Image.LANCZOS).convert('RGB')


def feature():
    w, h = 1024, 500
    img = Image.new('RGBA', (w, h), BG)
    d = ImageDraw.Draw(img)
    # 아래쪽 넓은 언덕
    d.ellipse([-260, 360, w + 260, 900], fill=FAR_HILL)
    # 왼쪽 아이콘 (둥근 모서리)
    ic = render(bg='round').resize((250, 250), Image.LANCZOS)
    img.alpha_composite(ic, (110, 95))
    d.text((410, 135), '하나님앞에서', font=font(True, 76), fill=CROSS)
    d.text((414, 250), '교회 훈련 12주 체크표', font=font(False, 38), fill=SOFT)
    d.text((414, 305), '매주 체크를 폰으로 간편하게', font=font(False, 30), fill=SOFT)
    return img.convert('RGB')


def main():
    os.makedirs(OUT, exist_ok=True)
    icon().save(os.path.join(OUT, 'play-icon-512.png'), optimize=True)
    feature().save(os.path.join(OUT, 'play-feature-1024x500.png'), optimize=True)
    print('스토어 그림을 만들었어요:', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
