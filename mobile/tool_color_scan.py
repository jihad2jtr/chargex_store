import collections
import re
from pathlib import Path

root = Path(r"d:\project\jgo_store\mobile\lib")
pat = re.compile(r"Color\(0x([A-Fa-f0-9]{8})\)")
counts = collections.Counter()
for p in root.rglob("*.dart"):
    if p.name == "app_colors.dart":
        continue
    text = p.read_text(encoding="utf-8")
    found = pat.findall(text)
    counts.update(h.upper() for h in found)
print("HITS", sum(counts.values()), "UNIQUE", len(counts))
for h, n in counts.most_common():
    print(f"{n:4} 0x{h}")
