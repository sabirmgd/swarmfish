# SwarmFish

**Multi-agent swarm intelligence engine for [Claude Code](https://claude.ai/code).**

Predict outcomes by simulating how diverse stakeholders interact. Feed in a topic, and SwarmFish builds a knowledge graph, generates agent personas, runs a multi-round simulation, and produces a prediction report with an interactive HTML dashboard.

Inspired by [MiroFish](https://github.com/666ghj/MiroFish) — reimagined as a Claude Code plugin with file-based knowledge graphs and zero external services.

## Install

```bash
# Add the marketplace
/plugin marketplace add sabirsalah/swarmfish

# Install the plugin
/plugin install swarmfish@swarmfish

# Install optional tools (graphviz + networkx)
/swarmfish:swarm setup
```

**Or test locally:**
```bash
git clone https://github.com/sabirsalah/swarmfish.git
claude --plugin-dir ./swarmfish
```

## Quick Start

```bash
# 1. Initialize a simulation from a topic
/swarmfish:swarm init "How will the developer community react to a new open-source AI model release?"

# 2. Run the simulation
/swarmfish:swarm run

# 3. Generate prediction report
/swarmfish:swarm report

# 4. Open visual dashboard
/swarmfish:swarm dashboard

# 5. Chat with any agent
/swarmfish:swarm chat "OpenAI"
```

## What It Does

```
Topic/Document
      │
      ▼
┌─────────────┐     ┌──────────────┐     ┌───────────────┐
│   Extract    │────▶│   Generate   │────▶│   Simulate    │
│  Entities &  │     │    Agent     │     │    Rounds     │
│ Relationships│     │   Personas   │     │  (parallel)   │
└─────────────┘     └──────────────┘     └───────┬───────┘
                                                  │
                    ┌──────────────┐     ┌────────▼────────┐
                    │   Generate   │◀────│  Update Graph   │
                    │   Report     │     │    Memory       │
                    └──────┬───────┘     └─────────────────┘
                           │
                    ┌──────▼───────┐
                    │  Dashboard   │
                    │  (HTML/D3)   │
                    └──────────────┘
```

## Commands

| Command | Description |
|---------|-------------|
| `init <topic>` | Seed a new simulation from a topic or scenario file |
| `run [sim-id]` | Execute simulation rounds with agent interactions |
| `report [sim-id]` | Generate a comprehensive prediction report |
| `dashboard [sim-id]` | Build and open HTML visualization dashboard |
| `chat <agent>` | Interview a specific agent in character |
| `graph [sim-id]` | Inspect and query the knowledge graph |
| `metrics [sim-id]` | Run NetworkX graph metrics (PageRank, centrality) |
| `svg [sim-id]` | Generate force-directed SVG graph |
| `pdf [sim-id]` | Export report as professional PDF |
| `query <name>` | Query actions with jq (stats, sentiment, by-agent...) |
| `status [sim-id]` | Show simulation status or list all |
| `inject <event>` | Inject a God's Eye event into next round |
| `check` | Verify tools and dependencies |
| `setup` | Install optional dependencies |
| `config` | Show and validate configuration |

## Configuration

On first use, SwarmFish creates `.swarmfish/config.yaml` in your project. Edit it to customize:

```yaml
# Which Claude model for each phase
models:
  entity_extraction: "sonnet"
  persona_generation: "sonnet"
  simulation: "haiku"        # Fast for many agent turns
  report: "opus"             # Best quality for synthesis

# Simulation settings
simulation:
  max_rounds: 10
  max_agents: 15
  parallel_agents: 3         # How many agents run in parallel

# Dashboard
dashboard:
  auto_open: true
  theme: "dark"
```

See [`config/default-config.yaml`](config/default-config.yaml) for all options.

## Scenarios

Create reusable scenarios as YAML files:

```yaml
name: "Market Reaction Analysis"
seed:
  type: "text"
  content: |
    Breaking: Company X announces...
prediction_question: |
  How will stakeholders react?
interventions:
  - round: 5
    event: "Breaking: New regulation announced..."
```

See [`scenarios/example.yaml`](scenarios/example.yaml) for a full example.

## Dashboard

The HTML dashboard (auto-generated, opens in browser) includes:

| Tab | Visualization |
|-----|---------------|
| **Graph** | D3.js force-directed entity relationship graph |
| **Simulation** | Round-by-round action timeline with agent cards |
| **Agents** | Persona cards with stats, MBTI, activity bars |
| **Sentiment** | Chart.js line chart of opinion evolution |
| **Report** | Rendered prediction report |
| **Chat** | Interview conversation history |

## Optional Tools

| Tool | Install | What it adds |
|------|---------|-------------|
| `graphviz` | `brew install graphviz` | Force-directed SVG graph layouts |
| `networkx` | `pip install networkx numpy` | PageRank, centrality, community detection |
| `md-to-pdf` | `npm i -g md-to-pdf` | Professional PDF export |
| `jq` | `brew install jq` | CLI action queries |

Run `/swarmfish:swarm setup` to install all optional tools interactively.

## How It Works

SwarmFish replaces MiroFish's Zep Cloud (paid) with file-based JSON knowledge graphs and Claude as the semantic search engine. Instead of a Vue.js frontend, it generates a self-contained HTML dashboard.

| MiroFish Component | SwarmFish Equivalent |
|---|---|
| Zep Knowledge Graph | `graph/*.json` files |
| Zep Semantic Search | Claude reads graph + reasons over it |
| OASIS Agent Simulation | Claude Code agent teams (parallel) |
| Vue.js Frontend | Self-contained HTML dashboard (D3 + Chart.js) |
| Python/Flask Backend | Claude Code skill orchestration |

## Plugin Structure

```
swarmfish/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # Marketplace catalog
├── skills/swarm/SKILL.md    # Main skill (/swarmfish:swarm)
├── agents/                  # 5 specialized agents
├── templates/               # 10 prompt templates + dashboard HTML
├── scripts/                 # 4 analysis scripts (Python + Bash)
├── bin/                     # CLI tools (added to PATH)
├── config/                  # Default configuration
└── scenarios/               # Example scenarios
```

## License

MIT
