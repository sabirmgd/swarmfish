# SwarmFish

Multi-agent swarm intelligence engine for Claude Code. Given a topic or scenario, SwarmFish builds a knowledge graph, generates stakeholder personas, runs a multi-round simulation, and produces a prediction report with an interactive HTML dashboard.

## Quick Usage

```
/swarmfish:swarm init "topic"   # Seed a simulation from a topic
/swarmfish:swarm run             # Execute simulation rounds
/swarmfish:swarm report          # Generate prediction report
/swarmfish:swarm dashboard       # Open interactive HTML dashboard
```

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `templates/` | Prompt templates and dashboard HTML scaffold |
| `scripts/` | Analysis scripts (Python + Bash) |
| `config/` | Default configuration (default-config.yaml) |
| `scenarios/` | Reusable scenario YAML files |
| `agents/` | Specialized agent definitions |
| `skills/` | Skill definitions (swarm SKILL.md) |
| `bin/` | CLI tools (swarmfish-check, swarmfish-setup) |

## Data Location

All user/simulation data is stored in `.swarmfish/` inside the project that uses the plugin (not inside the plugin itself). This includes simulation state, knowledge graphs, reports, and config overrides.

## Plugin Root

`${CLAUDE_PLUGIN_ROOT}` points to the plugin install directory. Use this to reference templates, scripts, and config files shipped with the plugin.
