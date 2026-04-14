#!/bin/bash
# Convert PDF to PNG (using macOS native CoreGraphics)
# Usage: pdf2png.sh file1.pdf [file2.pdf ...]

mode=$(osascript -e 'button returned of (display dialog "选择输出模式" buttons {"取消", "文件夹（每页一张）", "单图（纵向拼接）"} default button "单图（纵向拼接）")')
[[ -z "$mode" || "$mode" == "取消" ]] && exit 0

for f in "$@"; do
  [[ "$f" == *.pdf ]] || continue

  if [[ "$mode" == "单图（纵向拼接）" ]]; then
    output="${f%.pdf}.png"
    /usr/bin/python3 - "$f" "$output" <<'PYEOF'
import sys, os
from Quartz import (CGPDFDocumentCreateWithURL,
    CGPDFDocumentGetNumberOfPages, CGPDFDocumentGetPage,
    CGPDFPageGetBoxRect, kCGPDFMediaBox,
    CGColorSpaceCreateDeviceRGB, CGBitmapContextCreate,
    kCGImageAlphaPremultipliedLast, CGContextDrawPDFPage,
    CGContextScaleCTM, CGBitmapContextCreateImage,
    CGContextDrawImage, CGRectMake)
from CoreFoundation import CFURLCreateWithFileSystemPath, kCFURLPOSIXPathStyle
from AppKit import NSBitmapImageRep, NSPNGFileType

url = CFURLCreateWithFileSystemPath(None, sys.argv[1], kCFURLPOSIXPathStyle, False)
doc = CGPDFDocumentCreateWithURL(url)
n = CGPDFDocumentGetNumberOfPages(doc)
scale = 2.0
images, total_h, max_w = [], 0, 0
for i in range(1, n + 1):
    page = CGPDFDocumentGetPage(doc, i)
    r = CGPDFPageGetBoxRect(page, kCGPDFMediaBox)
    w, h = int(r.size.width * scale), int(r.size.height * scale)
    cs = CGColorSpaceCreateDeviceRGB()
    ctx = CGBitmapContextCreate(None, w, h, 8, 4 * w, cs, kCGImageAlphaPremultipliedLast)
    CGContextScaleCTM(ctx, scale, scale)
    CGContextDrawPDFPage(ctx, page)
    images.append((CGBitmapContextCreateImage(ctx), w, h))
    total_h += h
    max_w = max(max_w, w)
cs = CGColorSpaceCreateDeviceRGB()
ctx = CGBitmapContextCreate(None, max_w, total_h, 8, 4 * max_w, cs, kCGImageAlphaPremultipliedLast)
y = total_h
for img, w, h in images:
    y -= h
    CGContextDrawImage(ctx, CGRectMake(0, y, w, h), img)
rep = NSBitmapImageRep.alloc().initWithCGImage_(CGBitmapContextCreateImage(ctx))
data = rep.representationUsingType_properties_(NSPNGFileType, None)
data.writeToFile_atomically_(sys.argv[2], True)
PYEOF
    echo "Created: $output"
  else
    outdir="${f%.pdf}_pages"
    /usr/bin/python3 - "$f" "$outdir" <<'PYEOF'
import sys, os
from Quartz import (CGPDFDocumentCreateWithURL,
    CGPDFDocumentGetNumberOfPages, CGPDFDocumentGetPage,
    CGPDFPageGetBoxRect, kCGPDFMediaBox,
    CGColorSpaceCreateDeviceRGB, CGBitmapContextCreate,
    kCGImageAlphaPremultipliedLast, CGContextDrawPDFPage,
    CGContextScaleCTM, CGBitmapContextCreateImage)
from CoreFoundation import CFURLCreateWithFileSystemPath, kCFURLPOSIXPathStyle
from AppKit import NSBitmapImageRep, NSPNGFileType

url = CFURLCreateWithFileSystemPath(None, sys.argv[1], kCFURLPOSIXPathStyle, False)
doc = CGPDFDocumentCreateWithURL(url)
n = CGPDFDocumentGetNumberOfPages(doc)
outdir = sys.argv[2]
os.makedirs(outdir, exist_ok=True)
scale = 2.0
for i in range(1, n + 1):
    page = CGPDFDocumentGetPage(doc, i)
    r = CGPDFPageGetBoxRect(page, kCGPDFMediaBox)
    w, h = int(r.size.width * scale), int(r.size.height * scale)
    cs = CGColorSpaceCreateDeviceRGB()
    ctx = CGBitmapContextCreate(None, w, h, 8, 4 * w, cs, kCGImageAlphaPremultipliedLast)
    CGContextScaleCTM(ctx, scale, scale)
    CGContextDrawPDFPage(ctx, page)
    rep = NSBitmapImageRep.alloc().initWithCGImage_(CGBitmapContextCreateImage(ctx))
    data = rep.representationUsingType_properties_(NSPNGFileType, None)
    data.writeToFile_atomically_(os.path.join(outdir, f"page_{i:03d}.png"), True)
PYEOF
    echo "Created: $outdir/ ($(ls "$outdir" | wc -l | tr -d ' ') pages)"
  fi
done
