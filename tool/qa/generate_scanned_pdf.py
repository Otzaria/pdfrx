#!/usr/bin/env python3
"""Generate deterministic scanned-image-only PDF for Windows PDFium A/B QA."""
from pathlib import Path
import random
import sys
import zlib

WIDTH = 600
HEIGHT = 900
PAGES = 40


def stream(dictionary: bytes, data: bytes) -> bytes:
    return dictionary + b"\nstream\n" + data + b"\nendstream"


def generate(destination: Path) -> None:
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        (b"<< /Type /Pages /Count 40 /Kids [" +
         b" ".join(f"{3 + 3 * i} 0 R".encode("ascii") for i in range(PAGES)) + b"] >>"),
    ]
    for index in range(PAGES):
        page_id = 3 + 3 * index
        content_id = page_id + 1
        image_id = page_id + 2
        objects.append(
            (f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {WIDTH} {HEIGHT}] "
             f"/Resources << /XObject << /Im0 {image_id} 0 R >> >> "
             f"/Contents {content_id} 0 R >>").encode("ascii")
        )
        content = f"q\n{WIDTH} 0 0 {HEIGHT} 0 0 cm\n/Im0 Do\nQ\n".encode("ascii")
        objects.append(stream(f"<< /Length {len(content)} >>".encode("ascii"), content))
        rng = random.Random(0xC0FFEE + index)
        pixels = rng.randbytes(WIDTH * HEIGHT)
        compressed = zlib.compress(pixels, 1)
        image_dict = (f"<< /Type /XObject /Subtype /Image /Width {WIDTH} /Height {HEIGHT} "
                      f"/ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode "
                      f"/Length {len(compressed)} >>").encode("ascii")
        objects.append(stream(image_dict, compressed))

    output = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for obj_id, body in enumerate(objects, 1):
        offsets.append(len(output))
        output += f"{obj_id} 0 obj\n".encode("ascii") + body + b"\nendobj\n"
    xref_offset = len(output)
    output += f"xref\n0 {len(offsets)}\n0000000000 65535 f \n".encode("ascii")
    for position in offsets[1:]:
        output += f"{position:010d} 00000 n \n".encode("ascii")
    output += (f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\n"
               f"startxref\n{xref_offset}\n%%EOF\n").encode("ascii")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(output)
    print(f"QA_SCAN_PDF pages={PAGES} bytes={len(output)} dest={destination}")


if __name__ == "__main__":
    generate(Path(sys.argv[1] if len(sys.argv) > 1 else "test/assets/qa_scanned40.pdf"))
