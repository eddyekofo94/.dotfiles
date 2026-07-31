#!/bin/sh
set -eu

state=${HERDR_AGENT_OVERVIEW_FIXTURE_STATE:?}
mode=${HERDR_AGENT_OVERVIEW_FIXTURE_MODE:-normal}
session=''
if [ "${1:-}" = --session ]; then
  session=${2:-}
  shift 2
fi
printf '%s\t%s\n' "$session" "$*" >>"$state/calls"

if [ "$*" = "session list --json" ]; then
  beta_running=true
  [ "$mode" != session-missing ] || beta_running=false
  jq -cn --argjson beta_running "$beta_running" '{
    sessions:[
      {name:"alpha",running:true,socket_path:"/fixture/alpha.sock"},
      {name:"beta",running:$beta_running,socket_path:"/fixture/beta.sock"},
      {name:"gamma",running:true,socket_path:"/fixture/gamma.sock"},
      {name:"stopped",running:false,socket_path:"/fixture/stopped.sock"}
    ]
  }'
  exit
fi

if [ "$*" = "agent list" ]; then
  case "$session" in
    alpha)
      jq -cn '{
        id:"cli:agent:list",
        result:{type:"agent_list",agents:[{
          agent:"codex",agent_status:"idle",cwd:"/work/alpha",
          foreground_cwd:"/work/alpha",pane_id:"w1:p1",
          terminal_id:"term-alpha",focused:true,
          agent_session:{agent:"codex",kind:"id",source:"herdr:codex",value:"alpha-id"}
        }]}
      }'
      ;;
    beta)
      identity=beta-id
      [ "$mode" != stale-agent ] || identity=replacement-id
      jq -cn --arg identity "$identity" '{
        id:"cli:agent:list",
        result:{type:"agent_list",agents:[{
          agent:"codex",agent_status:"working",cwd:"/work/beta",
          foreground_cwd:"/work/beta",pane_id:"w1:p1",
          terminal_id:"term-beta",focused:false,
          agent_session:{agent:"codex",kind:"id",source:"herdr:codex",value:$identity}
        }]}
      }'
      ;;
    gamma)
      jq -cn '{
        id:"cli:agent:list",
        result:{type:"agent_list",agents:[{
          agent:"pi",agent_status:"idle",cwd:"/work/gamma",
          foreground_cwd:"/work/gamma",pane_id:"w1:p1",
          terminal_id:"term-gamma",focused:false,
          agent_session:{agent:"pi",kind:"file",source:"herdr:pi",value:"/sessions/gamma.jsonl"}
        }]}
      }'
      ;;
    *) exit 1 ;;
  esac
  exit
fi

case "$1 ${2:-}" in
  "agent read")
    [ "$session" = beta ] || exit 1
    [ "$3" = term-beta ] || exit 1
    requested=0
    while [ "$#" -gt 0 ]; do
      if [ "$1" = --lines ]; then
        requested=$2
        break
      fi
      shift
    done
    [ "$requested" -gt 0 ] || exit 1
    jq -cn --argjson lines "$requested" '{
      id:"cli:agent:read",
      result:{type:"pane_read",read:{
        pane_id:"w1:p1",format:"text",source:"recent_unwrapped",
        text:([range(1; $lines + 1) | "beta output line \(.)"] | join("\n")),
        truncated:false
      }}
    }'
    ;;
  "agent focus")
    [ "$session" = beta ] || exit 1
    [ "$3" = term-beta ] || exit 1
    printf '%s\n' "$session:$3" >>"$state/focus"
    jq -cn '{
      result:{type:"agent_info",agent:{
        agent:"codex",agent_status:"working",cwd:"/work/beta",
        foreground_cwd:"/work/beta",pane_id:"w1:p1",
        terminal_id:"term-beta",focused:true,
        agent_session:{agent:"codex",kind:"id",source:"herdr:codex",value:"beta-id"}
      }}
    }'
    ;;
  "pane send-text")
    [ "$session" = beta ] || exit 1
    [ "$3" = w1:p1 ] || exit 1
    printf '%s' "$4" >"$state/inserted"
    jq -cn '{result:{}}'
    ;;
  *)
    printf 'unexpected fixture call: session=%s args=%s\n' "$session" "$*" >&2
    exit 2
    ;;
esac
