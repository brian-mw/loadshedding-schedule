#!/usr/bin/env python3
"""
Fetch ESCOM loadshedding PDFs and, by default, parse new downloads.

Usage:
    python fetch_escom_pdfs.py [options]

    --all       Check all listings (default: newest only).
    --limit N   Limit listings checked.
    --since D   Only fetch weeks starting on/after ISO date D.
    --dry-run   Show actions without downloading or parsing.
    --no-parse  Download PDFs without parsing them.
    --data-dir  Set the output directory (default: ../data).

Existing week PDFs are skipped, so the script can be rerun safely.

TLS verification uses the system CA bundle plus ESCOM's missing Sectigo
intermediate certificate; verification is not disabled. See certs/README.md.
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import requests
from bs4 import BeautifulSoup

LISTING_URL = "https://www.escom.mw/loadshedding-program/"
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) escom-loadshedding-personal-archive/1.0"

HERE = Path(__file__).resolve().parent
INTERMEDIATE_CERT = HERE / "certs" / "sectigo-public-server-auth-ca-dv-r36.pem"
PARSE_SCRIPT = HERE / "parse_escom_pdf.py"

MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
    "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
}
DATE_RE = re.compile(
    r"(\d{1,2})(?:st|nd|rd|th)\s+(" + "|".join(MONTHS) + r")", re.IGNORECASE
)
YEAR_RE = re.compile(r"\b(20\d{2})\b")


def build_ca_bundle():
    """Concatenate the system CA bundle with the missing Sectigo intermediate."""
    system_bundle_candidates = [
        Path("/etc/ssl/certs/ca-certificates.crt"),
        Path("/etc/pki/tls/certs/ca-bundle.crt"),
    ]
    system_bundle = next((p for p in system_bundle_candidates if p.exists()), None)
    if system_bundle is None:
        import certifi
        system_bundle = Path(certifi.where())

    combined = tempfile.NamedTemporaryFile(
        mode="w", suffix=".pem", delete=False, prefix="escom-ca-bundle-"
    )
    combined.write(system_bundle.read_text())
    combined.write("\n")
    combined.write(INTERMEDIATE_CERT.read_text())
    combined.close()
    return combined.name


def fetch_listing(session):
    resp = session.get(LISTING_URL, timeout=30)
    resp.raise_for_status()
    return resp.text


def parse_listing(html):
    """Return [{title, package_url, wpdmdl, download_url, size_text}, ...] in page order."""
    soup = BeautifulSoup(html, "html.parser")
    entries = []
    for card in soup.select("div.link-template-default"):
        title_tag = card.select_one("h3.package-title a")
        dl_tag = card.select_one("a.wpdm-download-link")
        size_tag = card.select_one(".text-muted")
        if not title_tag or not dl_tag:
            continue
        download_url = dl_tag.get("data-downloadurl") or dl_tag.get("href")
        m = re.search(r"wpdmdl=(\d+)", download_url or "")
        entries.append({
            "title": title_tag.get_text(strip=True),
            "package_url": title_tag.get("href"),
            "wpdmdl": m.group(1) if m else None,
            "download_url": download_url,
            "size_text": size_tag.get_text(strip=True) if size_tag else None,
        })
    return entries


def parse_week_label(title):
    """Derive a 'YYYY-MM-DD_to_YYYY-MM-DD' (or single-day 'YYYY-MM-DD') label from a
    title like 'LOADSHEDDING PROGRAMME FROM MONDAY, 2ND NOVEMBER TO SATURDAY,
    7TH NOVEMBER 2026' or '... FOR SUNDAY, 25TH OCTOBER 2026'."""
    year_matches = YEAR_RE.findall(title)
    if not year_matches:
        return None
    year = int(year_matches[-1])

    dates = DATE_RE.findall(title)
    if not dates:
        return None

    def to_iso(day, month_name, year):
        return f"{year:04d}-{MONTHS[month_name.lower()]:02d}-{int(day):02d}"

    if len(dates) >= 2:
        start = to_iso(dates[0][0], dates[0][1], year)
        end = to_iso(dates[-1][0], dates[-1][1], year)
        return f"{start}_to_{end}"
    else:
        return to_iso(dates[0][0], dates[0][1], year)


def already_fetched(data_dir, week_label):
    return (data_dir / week_label / "source.pdf").exists()


def download_pdf(session, entry, dest_pdf, dry_run):
    print(f"  downloading -> {dest_pdf}")
    if dry_run:
        return
    dest_pdf.parent.mkdir(parents=True, exist_ok=True)
    with session.get(entry["download_url"], timeout=60, stream=True) as resp:
        resp.raise_for_status()
        with open(dest_pdf, "wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                f.write(chunk)


def run_parser(pdf_path, out_dir, python_exe, dry_run):
    print(f"  parsing -> {out_dir}")
    if dry_run:
        return
    subprocess.run(
        [python_exe, str(PARSE_SCRIPT), str(pdf_path), str(out_dir)],
        check=True,
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="check every listing, not just the newest")
    ap.add_argument("--limit", type=int, default=None, help="cap how many listings to consider")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-parse", action="store_true", help="only download, skip parse_escom_pdf.py")
    ap.add_argument("--data-dir", default=str(HERE.parent / "data"))
    ap.add_argument("--since", default=None, help="only fetch weeks starting on/after this ISO date, e.g. 2026-06-01")
    args = ap.parse_args()

    since = args.since

    data_dir = Path(args.data_dir).resolve()
    limit = args.limit if args.limit is not None else (None if args.all else 1)

    ca_bundle = build_ca_bundle()
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    session.verify = ca_bundle

    print(f"fetching listing: {LISTING_URL}")
    html = fetch_listing(session)
    entries = parse_listing(html)
    print(f"found {len(entries)} listing(s) on the page")

    if limit is not None:
        entries = entries[:limit]

    python_exe = sys.executable
    fetched, skipped, failed = 0, 0, 0

    for entry in entries:
        title = entry["title"]
        week_label = parse_week_label(title)
        if not week_label:
            print(f"- could not parse a date from title, skipping: {title!r}")
            failed += 1
            continue

        start_date = week_label.split("_to_")[0]
        if since and start_date < since:
            continue

        if already_fetched(data_dir, week_label):
            print(f"- {week_label}: already have it, skipping ({title})")
            skipped += 1
            continue

        print(f"+ {week_label}: {title}")
        out_dir = data_dir / week_label
        pdf_path = out_dir / "source.pdf"
        try:
            download_pdf(session, entry, pdf_path, args.dry_run)
            if not args.no_parse:
                run_parser(pdf_path, out_dir, python_exe, args.dry_run)
            fetched += 1
        except Exception as e:
            print(f"  FAILED: {e}")
            failed += 1
        if not args.dry_run and len(entries) > 1:
            time.sleep(1)  # be polite to the server on multi-item runs

    print(f"\ndone: {fetched} fetched, {skipped} already had, {failed} failed")


if __name__ == "__main__":
    main()
