#!/usr/bin/env python3
"""Fetch a web article and save it as markdown in ~/Documents."""

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

import requests


def slugify(text):
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text).strip("-")
    return text


def html_to_markdown(html_block, base_url=""):
    def _resolve_link(m):
        href, text = m.group(1), m.group(2)
        if base_url and href.startswith("/"):
            href = base_url.rstrip("/") + href
        return f"[{text}]({href})"

    text = re.sub(r"<a[^>]*href=\"([^\"]*)\"[^>]*>(.*?)</a>", _resolve_link, html_block)
    text = re.sub(r"<em>(.*?)</em>", r"*\1*", text)
    text = re.sub(r"<i>(.*?)</i>", r"*\1*", text)
    text = re.sub(r"<strong>(.*?)</strong>", r"**\1**", text)
    text = re.sub(r"<b>(.*?)</b>", r"**\1**", text)
    text = re.sub(r"<[^>]+>", "", text)
    for entity, char in [
        ("&amp;", "&"),
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&quot;", '"'),
        ("&#x27;", "'"),
        ("&nbsp;", " "),
        ("&#039;", "'"),
    ]:
        text = text.replace(entity, char)
    return text.strip()


def extract_jsonld_meta(html):
    title = author = date = ""
    for m in re.finditer(
        r'<script type="application/ld\+json">(.*?)</script>', html, re.DOTALL
    ):
        try:
            d = json.loads(m.group(1))
            if isinstance(d, dict) and d.get("@type") in ("NewsArticle", "Article"):
                title = d.get("headline", "")
                authors = d.get("author", [])
                if isinstance(authors, list):
                    author = ", ".join(a.get("name", "") for a in authors)
                elif isinstance(authors, dict):
                    author = authors.get("name", "")
                date = d.get("datePublished", "")
                if date:
                    date = date.split("T")[0]
        except (json.JSONDecodeError, KeyError):
            pass
    return title, author, date


def extract_og_meta(html):
    title = author = ""
    m = re.search(r'<meta[^>]*property="og:title"[^>]*content="([^"]*)"', html)
    if m:
        title = m.group(1)
    m = re.search(r'<meta[^>]*name="author"[^>]*content="([^"]*)"', html)
    if m:
        author = m.group(1)
    return title, author


def extract_article(html, base_url=""):
    """Try multiple strategies to extract article paragraphs."""
    paragraphs = []

    # Strategy 1: Verge-style article-body-component divs
    article_match = re.search(r"<article[^>]*>(.*?)</article>", html, re.DOTALL)
    source = article_match.group(1) if article_match else html

    for match in re.finditer(
        r'<div[^>]*class="[^"]*article-body-component[^"]*"[^>]*>(.*?)</div>',
        source,
        re.DOTALL,
    ):
        block = match.group(1)
        h_match = re.search(r"<h([2-4])[^>]*>(.*?)</h\1>", block, re.DOTALL)
        if h_match:
            level = int(h_match.group(1))
            text = re.sub(r"<[^>]+>", "", h_match.group(2)).strip()
            if text:
                paragraphs.append("#" * level + " " + text)
            continue
        p_match = re.search(r"<p[^>]*>(.*?)</p>", block, re.DOTALL)
        if p_match:
            text = html_to_markdown(p_match.group(1), base_url)
            if text:
                paragraphs.append(text)

    if len(paragraphs) > 3:
        return paragraphs

    # Strategy 2: Generic - all <p> tags inside <article>
    paragraphs = []
    for p_match in re.finditer(r"<p[^>]*>(.*?)</p>", source, re.DOTALL):
        text = html_to_markdown(p_match.group(1), base_url)
        if text and len(text) > 20:
            paragraphs.append(text)

    if len(paragraphs) > 3:
        return paragraphs

    # Strategy 3: Broadest - all <p> tags in the page with length filter
    paragraphs = []
    for p_match in re.finditer(r"<p[^>]*>(.*?)</p>", html, re.DOTALL):
        text = html_to_markdown(p_match.group(1), base_url)
        if text and len(text) > 40:
            paragraphs.append(text)

    return paragraphs


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <url>")
        sys.exit(1)

    url = sys.argv[1]
    parsed = urlparse(url)
    if not parsed.scheme:
        url = "https://" + url

    r = requests.get(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        },
        timeout=15,
    )
    r.raise_for_status()
    html = r.text

    # Extract metadata
    title, author, date = extract_jsonld_meta(html)
    if not title:
        og_title, og_author = extract_og_meta(html)
        title = title or og_title
        author = author or og_author
    if not title:
        m = re.search(r"<title>(.*?)</title>", html, re.DOTALL)
        title = re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else parsed.netloc

    # Extract content
    base_url = f"{parsed.scheme}://{parsed.netloc}"
    paragraphs = extract_article(html, base_url)
    if not paragraphs:
        print("Error: could not extract article content", file=sys.stderr)
        sys.exit(1)

    # Build markdown
    md = f"# {title}\n\n"
    meta_parts = []
    if author:
        meta_parts.append(f"**By {author}**")
    if date:
        meta_parts.append(date)
    meta_parts.append(f"Source: {url}")
    md += " | ".join(meta_parts) + "\n\n---\n\n"
    md += "\n\n".join(paragraphs) + "\n"

    # Write to ~/Documents
    slug = slugify(title)[:80]
    out_dir = Path.home() / "Documents"
    out_dir.mkdir(exist_ok=True)
    out_path = out_dir / f"{slug}.md"

    out_path.write_text(md)
    print(f"{out_path}")


if __name__ == "__main__":
    main()
