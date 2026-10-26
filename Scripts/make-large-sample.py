#!/usr/bin/env python3
"""Generate a large markdown file for performance testing.

Usage: Scripts/make-large-sample.py [output.md] [target_megabytes]
Defaults: Samples/large.md, 10 MB (git-ignored).
"""
import os
import sys

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "Samples", "large.md")
target = int(float(sys.argv[2]) * 1024 * 1024) if len(sys.argv) > 2 else 10 * 1024 * 1024

MERMAID = """```mermaid
flowchart LR
    A[Start {n}] --> B{{Check}}
    B -->|yes| C[Done]
    B -->|no| A
```
"""

CODE = {
    "swift": "func f{n}(_ x: Int) -> Int {{\n    return x * {n} + 1\n}}",
    "python": "def f{n}(x):\n    return x * {n} + 1",
    "javascript": "const f{n} = (x) => x * {n} + 1;",
    "rust": "fn f{n}(x: i64) -> i64 {{ x * {n} + 1 }}",
}

def section(n: int) -> str:
    lang = list(CODE)[n % len(CODE)]
    parts = [
        f"## Section {n}\n",
        f"Paragraph {n} with *emphasis*, **strong**, `code`, ~~strike~~, a [link](https://example.com/{n}) "
        f"and an autolink https://example.org/{n}. Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
        f"sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\n",
        "| Col A | Col B | Col C |\n|:--|:-:|--:|\n" + "".join(f"| {n}.{r} | b{r} | {r*n} |\n" for r in range(4)),
        "- [x] done item\n- [ ] todo item\n  - nested\n",
        f"```{lang}\n{CODE[lang].format(n=n)}\n```\n",
        f"> Quote {n}: the quick brown fox jumps over the lazy dog.[^{n}]\n",
        f"[^{n}]: Footnote text for section {n}.\n",
    ]
    if n % 500 == 0:
        parts.append(MERMAID.format(n=n))
    return "\n".join(parts) + "\n"

written = 0
n = 0
with open(out, "w", encoding="utf-8") as f:
    f.write("# Large sample\n\nGenerated for performance testing.\n\n")
    while written < target:
        s = section(n)
        f.write(s)
        written += len(s.encode("utf-8"))
        n += 1
print(f"Wrote {os.path.abspath(out)}: {n} sections, ~{written / 1024 / 1024:.1f} MB")
