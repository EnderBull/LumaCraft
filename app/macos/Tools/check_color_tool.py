"""Smoke-check native HEIF, orientation and ICC output on the CI Mac."""

from pathlib import Path
import struct
import subprocess
import sys

helper = sys.argv[1]
fixtures = Path("test/fixtures/heic")


def decode(filename, edge):
    data = subprocess.check_output([helper, str(fixtures / filename), str(edge)])
    magic, width, height, icc_length = struct.unpack_from("<4sIII", data)
    icc = data[16:16 + icc_length]
    assert magic == b"LMC1"
    assert len(icc) >= 128 and icc[36:40] == b"acsp" and icc[16:20] == b"RGB "
    assert len(data) == 16 + len(icc) + width * height * 4
    return width, height, icc


normal = decode("orientation-1.heic", 0)
rotated = decode("orientation-6.heic", 0)
assert normal[0] == rotated[1] and normal[1] == rotated[0]
p3 = decode("display-p3-10bit.heic", 128)
assert max(p3[:2]) <= 128 and p3[2] == normal[2]
print("ImageIO decoded HEIF orientation and returned sRGB ICC for Display P3")
