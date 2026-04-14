#!/bin/bash
# SwarmFish Action Query Tool - Query simulation actions using jq
# Usage:
#   ./query_actions.sh <sim-dir> <query>
#
# Queries:
#   stats               Overall action statistics
#   by-agent            Action count per agent
#   by-round            Action count per round
#   by-type             Action count per action type
#   sentiment           Average sentiment per agent
#   timeline            Chronological action summary
#   agent <name>        All actions by a specific agent
#   round <n>           All actions in a specific round
#   search <term>       Search action content for a term
#   top-posts           Most-replied-to posts
#   conflicts           Actions with negative sentiment

set -euo pipefail

SIM_DIR="${1:?Usage: query_actions.sh <sim-dir> <query>}"
QUERY="${2:-stats}"
ACTIONS="$SIM_DIR/actions.jsonl"

if [[ ! -f "$ACTIONS" ]]; then
  echo "No actions.jsonl found in $SIM_DIR"
  exit 1
fi

case "$QUERY" in
  stats)
    echo "=== Action Statistics ==="
    echo -n "Total actions: "; jq -s 'length' "$ACTIONS"
    echo -n "Rounds: "; jq -s '[.[].round] | unique | length' "$ACTIONS"
    echo -n "Active agents: "; jq -s '[.[].agent_name] | unique | length' "$ACTIONS"
    echo -n "Action types: "; jq -s '[.[].action.type] | unique' "$ACTIONS"
    echo -n "Avg sentiment: "; jq -s '[.[].action.sentiment // 0] | add / length | . * 100 | round / 100' "$ACTIONS"
    ;;

  by-agent)
    echo "=== Actions Per Agent ==="
    jq -s 'group_by(.agent_name) | map({agent: .[0].agent_name, count: length}) | sort_by(-.count)' "$ACTIONS"
    ;;

  by-round)
    echo "=== Actions Per Round ==="
    jq -s 'group_by(.round) | map({round: .[0].round, count: length, agents: [.[].agent_name] | unique})' "$ACTIONS"
    ;;

  by-type)
    echo "=== Actions Per Type ==="
    jq -s 'group_by(.action.type) | map({type: .[0].action.type, count: length}) | sort_by(-.count)' "$ACTIONS"
    ;;

  sentiment)
    echo "=== Average Sentiment Per Agent ==="
    jq -s 'group_by(.agent_name) | map({agent: .[0].agent_name, avg_sentiment: ([.[].action.sentiment // 0] | add / length | . * 100 | round / 100), actions: length}) | sort_by(.avg_sentiment)' "$ACTIONS"
    ;;

  timeline)
    echo "=== Action Timeline ==="
    jq -s '.[] | "R\(.round) | \(.agent_name) | \(.action.type) | \(.action.content[:80])"' "$ACTIONS"
    ;;

  agent)
    AGENT="${3:?Usage: query_actions.sh <sim-dir> agent <name>}"
    echo "=== Actions by $AGENT ==="
    jq -s "[.[] | select(.agent_name | test(\"$AGENT\"; \"i\"))]" "$ACTIONS"
    ;;

  round)
    ROUND="${3:?Usage: query_actions.sh <sim-dir> round <number>}"
    echo "=== Round $ROUND ==="
    jq -s "[.[] | select(.round == $ROUND)]" "$ACTIONS"
    ;;

  search)
    TERM="${3:?Usage: query_actions.sh <sim-dir> search <term>}"
    echo "=== Search: $TERM ==="
    jq -s "[.[] | select(.action.content | test(\"$TERM\"; \"i\"))] | .[] | {round, agent: .agent_name, type: .action.type, content: .action.content[:120]}" "$ACTIONS"
    ;;

  top-posts)
    echo "=== Most Referenced Posts ==="
    jq -s '[.[] | select(.action.in_reply_to != null) | .action.in_reply_to] | group_by(.) | map({post_id: .[0], replies: length}) | sort_by(-.replies) | .[:10]' "$ACTIONS"
    ;;

  conflicts)
    echo "=== Negative Sentiment Actions ==="
    jq -s '[.[] | select((.action.sentiment // 0) < -0.3)] | .[] | {round, agent: .agent_name, sentiment: .action.sentiment, content: .action.content[:100]}' "$ACTIONS"
    ;;

  *)
    echo "Unknown query: $QUERY"
    echo "Available: stats, by-agent, by-round, by-type, sentiment, timeline, agent <name>, round <n>, search <term>, top-posts, conflicts"
    exit 1
    ;;
esac
