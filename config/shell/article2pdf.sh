#!/usr/bin/env python3
"""Convert a web article to PDF via article2md + Brave headless."""

import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <url>")
        sys.exit(1)

    url = sys.argv[1]

    # Run article2md to get the markdown file
    result = subprocess.run(
        ["article2md", url], capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        print(f"article2md failed: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    md_path = Path(result.stdout.strip())
    if not md_path.exists():
        print(f"Markdown file not found: {md_path}", file=sys.stderr)
        sys.exit(1)

    md_content = md_path.read_text()
    pdf_path = md_path.with_suffix(".pdf")

    # Convert markdown to styled HTML
    html = md_to_html(md_content)

    # Write temp HTML and print to PDF via Brave
    with tempfile.NamedTemporaryFile(suffix=".html", mode="w", delete=False) as f:
        f.write(html)
        tmp_html = f.name

    try:
        subprocess.run(
            [
                "brave",
                "--headless",
                "--disable-gpu",
                "--no-sandbox",
                "--run-all-compositor-stages-before-draw",
                "--virtual-time-budget=5000",
                f"--print-to-pdf={pdf_path}",
                "--no-pdf-header-footer",
                tmp_html,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
    finally:
        Path(tmp_html).unlink(missing_ok=True)

    if not pdf_path.exists():
        print("Error: PDF was not created", file=sys.stderr)
        sys.exit(1)

    print(f"{pdf_path}")


def md_to_html(md):
    """Convert markdown text to styled HTML."""
    import re

    lines = md.split("\n")
    body_parts = []

    for line in lines:
        if not line.strip():
            continue
        if line.startswith("---"):
            body_parts.append("<hr>")
            continue
        if line.startswith("#### "):
            body_parts.append(f"<h4>{escape(line[5:])}</h4>")
            continue
        if line.startswith("### "):
            body_parts.append(f"<h3>{escape(line[4:])}</h3>")
            continue
        if line.startswith("## "):
            body_parts.append(f"<h2>{escape(line[3:])}</h2>")
            continue
        if line.startswith("# "):
            body_parts.append(f"<h1>{escape(line[2:])}</h1>")
            continue

        # Process inline markdown
        text = escape(line)
        # Bold
        text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
        # Italic
        text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
        # Links
        text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)

        body_parts.append(f"<p>{text}</p>")

    body = "\n".join(body_parts)

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {{
    font-family: Georgia, 'Times New Roman', serif;
    max-width: 700px;
    margin: 40px auto;
    padding: 0 20px;
    line-height: 1.7;
    color: #1a1a1a;
    font-size: 17px;
  }}
  h1 {{
    font-size: 2em;
    line-height: 1.2;
    margin-bottom: 0.3em;
  }}
  h2, h3, h4 {{
    margin-top: 1.5em;
  }}
  hr {{
    border: none;
    border-top: 1px solid #ccc;
    margin: 1.5em 0;
  }}
  a {{
    color: #1a0dab;
    text-decoration: underline;
  }}
  p {{
    margin: 1em 0;
  }}
</style>
</head>
<body>
{body}
</body>
</html>"""


def escape(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


if __name__ == "__main__":
    main()
