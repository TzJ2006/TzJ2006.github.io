#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess

def compress_with_pngquant(input_path: str, quality_low: int = 60, quality_high: int = 80):
    """
    使用 pngquant 压缩 PNG 文件。将输出写到 base.png
    如果输入是 JPEG，会先临时转为 PNG 后再用 pngquant 压缩。
    在压缩完成后，删除原本的 .jpg/.jpeg 文件。
    """
    if not os.path.isfile(input_path):
        print(f"Error: 文件未找到：{input_path}")
        return

    base, ext = os.path.splitext(input_path)
    ext_lower = ext.lower()
    tmp_png = None
    is_jpeg = False

    # 如果是 JPEG，则先转换为临时 PNG
    if ext_lower in (".jpg", ".jpeg"):
        from PIL import Image
        try:
            img = Image.open(input_path)
            tmp_png = f"{base}_tmp.png"
            img.save(tmp_png, format="PNG")
            source_png = tmp_png
            is_jpeg = True
        except Exception as e:
            print(f"Error: JPEG 转 PNG 失败：{e}")
            return
    elif ext_lower == ".png":
        source_png = input_path
    else:
        print(f"Error: 仅支持 .jpg/.jpeg/.png 文件，当前扩展名：{ext}")
        return

    output_path = f"{base}.png"
    try:
        subprocess.run([
            "pngquant",
            f"--quality={quality_low}-{quality_high}",
            "--output", output_path,
            "--force",
            "--speed", "1",
            source_png
        ], check=True)
        print(f"✔ 压缩完成：{output_path}")

        # 如果源文件为 JPEG，删除原始 .jpg/.jpeg
        if is_jpeg and os.path.isfile(input_path):
            os.remove(input_path)
            print(f"✖ 已删除原文件：{input_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error: pngquant 压缩失败：{e}")
    finally:
        if tmp_png and os.path.isfile(tmp_png):
            os.remove(tmp_png)

def main():
    if len(sys.argv) < 2:
        print("用法: python compress_image.py file1 [file2 ...]")
        sys.exit(1)

    files = sys.argv[1:]

    for f in files:
        compress_with_pngquant(f)

if __name__ == "__main__":
    main()
