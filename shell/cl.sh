# cl <account> [claude args...]: run Claude Code as another account (a = default ~/.claude).
cl() {
  local account="${1:?usage: cl <account> [claude args...]}"
  shift
  if [[ "$account" == a ]]; then
    claude "$@"
  else
    [[ -d "$HOME/.claude-$account" ]] || { echo "no profile: agent profile $account" >&2; return 1; }
    CLAUDE_CONFIG_DIR="$HOME/.claude-$account" claude "$@"
  fi
}
