# Deferred Scripts

Scripts from NixOS that are not yet migrated. Each has dependencies that need to be set up first.

## print

Sends files to Brother DCP-7060D printer via CUPS. Supports USB (default) and network (`--network` flag via router at 192.168.1.1:9100).

Dependencies: CUPS service, Brother drivers (brlaser, brgenml1 from AUR). See migration 10.4.

Usage: `print <file> [--network] [-- lp-options...]`

## scan2pdf / scan2png

Scans documents using Brother DCP-7060D scanner, runs OCR with tesseract, then uses Ollama or Claude API to auto-categorize and file the result on NAS.

Dependencies: SANE + brscan4 (AUR), tesseract, imagemagick, Ollama or Claude Agent SDK. Scanner requires sudo NOPASSWD for scanimage. See migration 10.4.

## pdf-order

Reads PDFs using Ollama vision model, auto-sorts them into categorized folders on NAS at /mnt/syno/scans/.

Dependencies: Ollama running with a vision model, ocrmypdf, imagemagick, NAS mounted.

## shorten

CLI for creating short URLs via self-hosted chhoto-url at s.clearcmos.com. Copies result to clipboard.

Dependencies: API key secret (was in agenix, needs secrets management). See migration 9.1.

## meds

Medication tracker CLI that talks to a FastAPI backend running on misc.home.arpa:8110.

Dependencies: med-tracker service running. See migration 7.x.

## fcm-test

Sends test Firebase Cloud Messaging push notifications to phone.

Dependencies: python firebase-admin package, Firebase service account secret. See migration 9.1.
