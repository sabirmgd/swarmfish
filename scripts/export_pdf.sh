#!/bin/bash
# SwarmFish PDF Export - Converts report.md or dashboard.html to PDF
# Usage:
#   ./export_pdf.sh <sim-dir>                    # Export report.md as PDF
#   ./export_pdf.sh <sim-dir> --dashboard         # Export dashboard.html as PDF
#   ./export_pdf.sh <sim-dir> --output report.pdf  # Custom output path

set -euo pipefail

SIM_DIR="${1:?Usage: export_pdf.sh <sim-dir> [--dashboard] [--output <path>]}"
MODE="report"
OUTPUT=""

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dashboard) MODE="dashboard"; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ "$MODE" == "report" ]]; then
  INPUT="$SIM_DIR/report.md"
  [[ -z "$OUTPUT" ]] && OUTPUT="$SIM_DIR/report.pdf"

  if [[ ! -f "$INPUT" ]]; then
    echo "Error: $INPUT not found. Run /swarm report first."
    exit 1
  fi

  if command -v md-to-pdf &>/dev/null; then
    echo "Generating PDF from report.md using md-to-pdf..."
    md-to-pdf "$INPUT" --dest "$OUTPUT" \
      --css "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; color: #1a1a1a; line-height: 1.7; } h1 { border-bottom: 2px solid #333; padding-bottom: 8px; } h2 { color: #2563eb; margin-top: 2em; } blockquote { border-left: 3px solid #2563eb; padding: 8px 16px; background: #f8fafc; } code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; } table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid #e2e8f0; padding: 8px 12px; text-align: left; } th { background: #f1f5f9; }" \
      2>/dev/null
    echo "PDF saved: $OUTPUT"
  elif command -v weasyprint &>/dev/null; then
    echo "Generating PDF from report.md using weasyprint..."
    # Convert md to html first, then to PDF
    python3 -c "
import sys
try:
    import markdown
    html = markdown.markdown(open('$INPUT').read(), extensions=['tables','fenced_code'])
except ImportError:
    html = '<pre>' + open('$INPUT').read() + '</pre>'
styled = f'''<html><head><style>
body {{ font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; line-height: 1.7; }}
h1 {{ border-bottom: 2px solid #333; }} h2 {{ color: #2563eb; }}
</style></head><body>{html}</body></html>'''
open('/tmp/swarm_report.html', 'w').write(styled)
"
    weasyprint /tmp/swarm_report.html "$OUTPUT" 2>/dev/null
    rm -f /tmp/swarm_report.html
    echo "PDF saved: $OUTPUT"
  else
    echo "Error: Neither md-to-pdf nor weasyprint found."
    echo "Install: npm install -g md-to-pdf  OR  pip install weasyprint"
    exit 1
  fi

elif [[ "$MODE" == "dashboard" ]]; then
  INPUT="$SIM_DIR/dashboard.html"
  [[ -z "$OUTPUT" ]] && OUTPUT="$SIM_DIR/dashboard.pdf"

  if [[ ! -f "$INPUT" ]]; then
    echo "Error: $INPUT not found. Run /swarm dashboard first."
    exit 1
  fi

  if command -v md-to-pdf &>/dev/null; then
    echo "Generating PDF from dashboard.html..."
    # md-to-pdf can handle HTML files too via puppeteer
    npx puppeteer-cli print "$INPUT" "$OUTPUT" --wait-until networkidle0 2>/dev/null || {
      echo "Fallback: opening dashboard in browser for manual PDF export"
      open "$INPUT"
      echo "Use Cmd+P in browser to save as PDF"
    }
  else
    echo "Opening dashboard in browser for manual PDF export (use Cmd+P)"
    open "$INPUT"
  fi
fi
