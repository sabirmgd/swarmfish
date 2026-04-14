#!/bin/bash
# SwarmFish Graph SVG Generator
# Generates a force-directed SVG using graphviz neato from simulation data
# Usage:
#   ./generate_graph_svg.sh <sim-dir>                  # Default neato layout
#   ./generate_graph_svg.sh <sim-dir> --layout fdp     # Alternative layout
#   ./generate_graph_svg.sh <sim-dir> --output graph.svg

set -euo pipefail

SIM_DIR="${1:?Usage: generate_graph_svg.sh <sim-dir> [--layout neato|fdp|sfdp] [--output <path>]}"
LAYOUT="neato"
OUTPUT=""

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --layout) LAYOUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$OUTPUT" ]] && OUTPUT="$SIM_DIR/graph.svg"

# Check graphviz is installed
if ! command -v neato &>/dev/null; then
  echo "Graphviz not installed. Install with: brew install graphviz"
  echo "Falling back to mermaid..."

  if command -v mmdc &>/dev/null; then
    # Generate mermaid syntax from graph data
    python3 -c "
import json, sys
from pathlib import Path

sim = Path('$SIM_DIR')
entities = json.loads((sim / 'graph' / 'entities.json').read_text())
if isinstance(entities, dict): entities = entities.get('entities', [])

rels_file = sim / 'graph' / 'relationships.json'
rels = json.loads(rels_file.read_text()) if rels_file.exists() else []
if isinstance(rels, dict): rels = rels.get('relationships', [])

# Build ID to short name map
names = {}
for e in entities:
    safe = e['name'].replace('\"', '').replace(' ', '_')[:20]
    names[e['id']] = safe

print('graph TD')
for e in entities:
    eid = e['id']
    name = e['name']
    etype = e.get('type', 'unknown')
    print(f'    {eid}[\"{name}<br/><small>{etype}</small>\"]')

for r in rels:
    src, tgt = r.get('source'), r.get('target')
    if src in names and tgt in names:
        label = r.get('type', 'RELATED')
        print(f'    {src} -->|\"{label}\"| {tgt}')
" > /tmp/swarm_graph.mmd

    OUTPUT_MERMAID="${OUTPUT%.svg}.svg"
    mmdc -i /tmp/swarm_graph.mmd -o "$OUTPUT_MERMAID" -t dark -b transparent 2>/dev/null
    rm -f /tmp/swarm_graph.mmd
    echo "Mermaid SVG saved: $OUTPUT_MERMAID"
  else
    echo "Neither graphviz nor mermaid-cli available."
    exit 1
  fi
  exit 0
fi

# Generate DOT file using Python script
DOT_FILE="/tmp/swarm_graph.dot"

python3 "$(dirname "$0")/graph_metrics.py" "$SIM_DIR" --format dot --output "$DOT_FILE" 2>/dev/null || {
  # Fallback: simple DOT generation without networkx
  python3 -c "
import json
from pathlib import Path

sim = Path('$SIM_DIR')
entities_file = sim / 'graph' / 'entities.json'
rels_file = sim / 'graph' / 'relationships.json'

entities = json.loads(entities_file.read_text()) if entities_file.exists() else []
if isinstance(entities, dict): entities = entities.get('entities', [])

rels = json.loads(rels_file.read_text()) if rels_file.exists() else []
if isinstance(rels, dict): rels = rels.get('relationships', [])

colors = {'person':'#4A90D9','organization':'#7B68EE','government':'#E74C3C','media':'#F39C12','group':'#2ECC71','concept':'#95A5A6','event':'#BDC3C7'}
sizes = {'high':0.8,'medium':0.6,'low':0.4}

lines = [
    'digraph SwarmFish {',
    '  graph [layout=$LAYOUT, overlap=false, splines=true, bgcolor=\"#0d1117\"];',
    '  node [style=filled, fontcolor=white, fontname=\"Helvetica\", fontsize=11];',
    '  edge [fontsize=9, fontcolor=\"#8b949e\", fontname=\"Helvetica\"];',
    '',
]

for e in entities:
    name = e.get('name','?').replace('\"','\\\\\"')
    color = colors.get(e.get('type',''), '#888888')
    size = sizes.get(e.get('importance','medium'), 0.6)
    lines.append(f'  \"{e[\"id\"]}\" [label=\"{name}\", fillcolor=\"{color}\", width={size}, height={size}];')

lines.append('')
rel_colors = {'SUPPORTS':'#2ECC71','OPPOSES':'#E74C3C','WORKS_FOR':'#3498DB','COLLABORATES_WITH':'#9B59B6','INFLUENCES':'#F39C12','REPORTS_ON':'#E67E22','REGULATES':'#C0392B','COMPETES_WITH':'#E74C3C'}

for r in rels:
    color = rel_colors.get(r.get('type',''), '#555555')
    lines.append(f'  \"{r[\"source\"]}\" -> \"{r[\"target\"]}\" [label=\"{r.get(\"type\",\"\")}\", color=\"{color}\"];')

lines.append('}')
open('$DOT_FILE', 'w').write('\\n'.join(lines))
" 2>/dev/null
}

# Render SVG
$LAYOUT -Tsvg "$DOT_FILE" -o "$OUTPUT" 2>/dev/null

# Also generate PNG for embedding in reports
PNG_OUTPUT="${OUTPUT%.svg}.png"
$LAYOUT -Tpng "$DOT_FILE" -o "$PNG_OUTPUT" 2>/dev/null || true

rm -f "$DOT_FILE"
echo "SVG saved: $OUTPUT (layout: $LAYOUT)"

# Open if requested
if [[ "${OPEN:-}" == "1" ]]; then
  open "$OUTPUT"
fi
