#!/usr/bin/env python3
"""
SwarmFish Graph Metrics - Computes network analysis metrics using NetworkX.

Usage:
  python graph_metrics.py <sim-dir>                    # Full analysis
  python graph_metrics.py <sim-dir> --round <n>        # Include memory updates up to round N
  python graph_metrics.py <sim-dir> --format json       # Output as JSON
  python graph_metrics.py <sim-dir> --format table      # Output as rich table

Requires: pip install networkx numpy
"""

import json
import sys
from pathlib import Path

try:
    import networkx as nx
except ImportError:
    print("NetworkX not installed. Run: pip install networkx numpy")
    print("Or skip graph metrics - the simulation works without it.")
    sys.exit(1)


def load_graph(sim_dir: Path, up_to_round: int | None = None) -> nx.DiGraph:
    """Load entities and relationships into a NetworkX directed graph."""
    G = nx.DiGraph()

    # Load entities
    entities_file = sim_dir / "graph" / "entities.json"
    if entities_file.exists():
        data = json.loads(entities_file.read_text())
        entities = data if isinstance(data, list) else data.get("entities", [])
        for e in entities:
            G.add_node(
                e["id"],
                name=e.get("name", e["id"]),
                type=e.get("type", "unknown"),
                importance=e.get("importance", "medium"),
                stance=e.get("stance", ""),
            )

    # Load relationships
    rels_file = sim_dir / "graph" / "relationships.json"
    if rels_file.exists():
        data = json.loads(rels_file.read_text())
        rels = data if isinstance(data, list) else data.get("relationships", [])
        for r in rels:
            if G.has_node(r["source"]) and G.has_node(r["target"]):
                G.add_edge(
                    r["source"],
                    r["target"],
                    type=r.get("type", "RELATED"),
                    strength=r.get("strength", "moderate"),
                    weight={"strong": 3, "moderate": 2, "weak": 1}.get(
                        r.get("strength", "moderate"), 2
                    ),
                )

    # Load memory updates (new relationships from simulation)
    updates_file = sim_dir / "graph" / "memory-updates.json"
    if updates_file.exists():
        updates = json.loads(updates_file.read_text())
        for update in updates:
            if up_to_round and update.get("round", 0) > up_to_round:
                continue
            for nr in update.get("updates", {}).get("new_relationships", []):
                src, tgt = nr.get("source"), nr.get("target")
                if src and tgt and G.has_node(src) and G.has_node(tgt):
                    G.add_edge(
                        src,
                        tgt,
                        type=nr.get("type", "RELATED"),
                        weight=2,
                        from_round=update.get("round"),
                    )

    return G


def compute_metrics(G: nx.DiGraph) -> dict:
    """Compute key graph metrics."""
    if len(G) == 0:
        return {"error": "Empty graph"}

    # Convert to undirected for some metrics
    G_undirected = G.to_undirected()

    metrics = {
        "summary": {
            "nodes": len(G),
            "edges": G.number_of_edges(),
            "density": round(nx.density(G), 4),
            "is_connected": nx.is_weakly_connected(G),
            "components": nx.number_weakly_connected_components(G),
        },
        "nodes": {},
    }

    # Degree centrality (who has most connections)
    degree_cent = nx.degree_centrality(G)

    # Betweenness centrality (who bridges communities)
    betweenness = nx.betweenness_centrality(G, weight="weight")

    # PageRank (recursive influence)
    try:
        pagerank = nx.pagerank(G, weight="weight")
    except Exception:
        pagerank = {n: 1.0 / len(G) for n in G}

    # Clustering coefficient (how tight-knit neighbors are)
    clustering = nx.clustering(G_undirected)

    # In-degree and out-degree (who receives vs sends influence)
    in_deg = dict(G.in_degree())
    out_deg = dict(G.out_degree())

    # Build per-node metrics
    for node_id in G.nodes():
        node_data = G.nodes[node_id]
        metrics["nodes"][node_id] = {
            "name": node_data.get("name", node_id),
            "type": node_data.get("type", "unknown"),
            "degree_centrality": round(degree_cent.get(node_id, 0), 4),
            "betweenness_centrality": round(betweenness.get(node_id, 0), 4),
            "pagerank": round(pagerank.get(node_id, 0), 4),
            "clustering_coefficient": round(clustering.get(node_id, 0), 4),
            "in_degree": in_deg.get(node_id, 0),
            "out_degree": out_deg.get(node_id, 0),
        }

    # Rankings
    metrics["rankings"] = {
        "most_connected": sorted(
            metrics["nodes"].items(),
            key=lambda x: x[1]["degree_centrality"],
            reverse=True,
        )[:5],
        "most_influential": sorted(
            metrics["nodes"].items(),
            key=lambda x: x[1]["pagerank"],
            reverse=True,
        )[:5],
        "key_bridges": sorted(
            metrics["nodes"].items(),
            key=lambda x: x[1]["betweenness_centrality"],
            reverse=True,
        )[:5],
    }

    # Community detection (Louvain if available, else greedy modularity)
    try:
        communities = list(nx.community.greedy_modularity_communities(G_undirected))
        metrics["communities"] = [
            {
                "id": i,
                "members": [
                    G.nodes[n].get("name", n) for n in sorted(c)
                ],
                "size": len(c),
            }
            for i, c in enumerate(communities)
        ]
    except Exception:
        metrics["communities"] = []

    return metrics


def generate_dot(G: nx.DiGraph, config: dict | None = None) -> str:
    """Generate Graphviz DOT format for neato/fdp rendering."""
    type_colors = {}
    if config:
        for et in config.get("entity_types", []):
            type_colors[et["name"]] = et.get("color", "#888888")

    rel_colors = {}
    if config:
        for rt in config.get("relationship_types", []):
            rel_colors[rt["name"]] = rt.get("color", "#888888")

    default_colors = [
        "#4A90D9", "#7B68EE", "#E74C3C", "#F39C12",
        "#2ECC71", "#95A5A6", "#E67E22", "#9B59B6",
    ]

    lines = [
        'digraph SwarmFish {',
        '  graph [layout=neato, overlap=false, splines=true, bgcolor="#0d1117"];',
        '  node [style=filled, fontcolor=white, fontname="Helvetica", fontsize=11];',
        '  edge [fontsize=9, fontcolor="#8b949e", fontname="Helvetica"];',
        '',
    ]

    # Nodes
    for i, (node_id, data) in enumerate(G.nodes(data=True)):
        ntype = data.get("type", "unknown")
        color = type_colors.get(ntype, default_colors[i % len(default_colors)])
        importance = data.get("importance", "medium")
        size = {"high": 0.8, "medium": 0.6, "low": 0.4}.get(importance, 0.6)
        name = data.get("name", node_id).replace('"', '\\"')
        lines.append(
            f'  "{node_id}" [label="{name}", fillcolor="{color}", '
            f'width={size}, height={size}];'
        )

    lines.append('')

    # Edges
    for src, tgt, data in G.edges(data=True):
        rel_type = data.get("type", "RELATED")
        color = rel_colors.get(rel_type, "#555555")
        weight = data.get("weight", 2)
        penwidth = {3: "2.0", 2: "1.2", 1: "0.8"}.get(weight, "1.2")
        lines.append(
            f'  "{src}" -> "{tgt}" [label="{rel_type}", '
            f'color="{color}", penwidth={penwidth}];'
        )

    lines.append('}')
    return '\n'.join(lines)


def format_table(metrics: dict) -> str:
    """Format metrics as a readable text table."""
    try:
        from rich.console import Console
        from rich.table import Table
        from io import StringIO

        buf = StringIO()
        console = Console(file=buf, force_terminal=True, width=120)

        # Summary
        s = metrics["summary"]
        console.print(f"\n[bold cyan]Graph Summary[/]")
        console.print(
            f"  Nodes: {s['nodes']}  |  Edges: {s['edges']}  |  "
            f"Density: {s['density']}  |  Components: {s['components']}"
        )

        # Node metrics table
        table = Table(title="Node Metrics", show_lines=False)
        table.add_column("Entity", style="bold")
        table.add_column("Type", style="dim")
        table.add_column("PageRank", justify="right")
        table.add_column("Betweenness", justify="right")
        table.add_column("Degree", justify="right")
        table.add_column("Clustering", justify="right")
        table.add_column("In/Out", justify="right")

        sorted_nodes = sorted(
            metrics["nodes"].items(),
            key=lambda x: x[1]["pagerank"],
            reverse=True,
        )
        for node_id, m in sorted_nodes:
            table.add_row(
                m["name"],
                m["type"],
                f"{m['pagerank']:.3f}",
                f"{m['betweenness_centrality']:.3f}",
                f"{m['degree_centrality']:.3f}",
                f"{m['clustering_coefficient']:.2f}",
                f"{m['in_degree']}/{m['out_degree']}",
            )
        console.print(table)

        # Communities
        if metrics.get("communities"):
            console.print("\n[bold cyan]Communities[/]")
            for c in metrics["communities"]:
                members = ", ".join(c["members"])
                console.print(f"  Group {c['id'] + 1}: {members}")

        return buf.getvalue()
    except ImportError:
        # Fallback without rich
        lines = ["\nGraph Metrics:"]
        lines.append(f"  Nodes: {metrics['summary']['nodes']}, Edges: {metrics['summary']['edges']}")
        for node_id, m in sorted(
            metrics["nodes"].items(), key=lambda x: x[1]["pagerank"], reverse=True
        ):
            lines.append(
                f"  {m['name']:20s} | PR:{m['pagerank']:.3f} | "
                f"BW:{m['betweenness_centrality']:.3f} | "
                f"Deg:{m['degree_centrality']:.3f}"
            )
        return "\n".join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="SwarmFish Graph Metrics")
    parser.add_argument("sim_dir", help="Simulation directory path")
    parser.add_argument("--round", type=int, help="Include updates up to this round")
    parser.add_argument("--format", choices=["json", "table", "dot"], default="table")
    parser.add_argument("--output", help="Output file path (default: stdout)")
    args = parser.parse_args()

    sim_dir = Path(args.sim_dir)
    if not sim_dir.exists():
        print(f"Error: {sim_dir} not found")
        sys.exit(1)

    G = load_graph(sim_dir, args.round)

    if args.format == "dot":
        # Load config for colors
        config = None
        config_file = Path(".swarm/config.yaml")
        if config_file.exists():
            try:
                import yaml
                config = yaml.safe_load(config_file.read_text())
            except ImportError:
                pass
        result = generate_dot(G, config)
    elif args.format == "json":
        metrics = compute_metrics(G)
        # Clean up rankings for JSON serialization
        for key in metrics.get("rankings", {}):
            metrics["rankings"][key] = [
                {"id": k, **v} for k, v in metrics["rankings"][key]
            ]
        result = json.dumps(metrics, indent=2)
    else:
        metrics = compute_metrics(G)
        result = format_table(metrics)

    if args.output:
        Path(args.output).write_text(result)
        print(f"Written to {args.output}")
    else:
        print(result)


if __name__ == "__main__":
    main()
