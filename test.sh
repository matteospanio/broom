#!/usr/bin/env bash
# Smoke test for broom. It runs against a throwaway $HOME with a minimal PATH
# and stub tools, so nothing on the real machine is touched.
set -euo pipefail

broom="$(cd "$(dirname "$0")" && pwd)/broom"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export HOME=$tmp/home XDG_CACHE_HOME='' XDG_DATA_HOME='' NO_COLOR=1
unset npm_config_cache CARGO_HOME GOCACHE ZSH CONDA_EXE
export PATH="$tmp/bin:/usr/bin:/bin"

# Stub tools record their arguments instead of doing anything.
mkdir -p "$tmp/bin"
for tool in uv pnpm conda pipx; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\n' "$tool" "$tmp" >"$tmp/bin/$tool"
  chmod +x "$tmp/bin/$tool"
done

mk()  { mkdir -p "$(dirname "$1")"; echo data >"$1"; }
age() { find "$@" -exec touch -d '40 days ago' {} +; }

C=$HOME/.cache D=$HOME/.local/share P=$HOME/code
mk "$D/Trash/files/junk.txt"
mk "$D/Trash/info/junk.txt.trashinfo"
mk "$C/thumbnails/large/old.png" && age "$C/thumbnails/large/old.png"
mk "$C/thumbnails/large/new.png"
mk "$C/pip/http/blob"
mk "$C/JetBrains/PyCharm2025.2/index"
mk "$C/JetBrains/PyCharm2025.10/index"
mk "$D/JetBrains/IntelliJIdea2024.3/plugins/x.jar"
mk "$D/JetBrains/IntelliJIdea2025.1/plugins/x.jar"
# stale projects: nothing touched for 40 days -> artifacts go
mk "$P/rusty/Cargo.toml" && mk "$P/rusty/target/debug/app" && age "$P/rusty"
mk "$P/web/package.json" && mk "$P/web/node_modules/lib/index.js" && age "$P/web"
mk "$P/py/pyproject.toml" && mk "$P/py/.venv/pyvenv.cfg" && age "$P/py"
# active projects: old artifacts, but a source file (even 4 levels deep) was edited -> kept
mk "$P/fresh/Cargo.toml" && mk "$P/fresh/target/debug/app" && age "$P/fresh"
mk "$P/fresh/src/main.rs"
mk "$P/active/.venv/pyvenv.cfg" && mk "$P/active/src/pkg/sub/mod.py" && age "$P/active"
mk "$P/active/src/pkg/sub/mod.py"
# not artifacts: no project marker, or inside a hidden dir -> kept
mk "$P/notrust/target/keep.txt" && age "$P/notrust"
mk "$P/.hidden/target/x" && mk "$P/.hidden/Cargo.toml" && age "$P/.hidden"

fails=0
pass() { echo "ok   - $*"; }
fail() { echo "FAIL - $*"; fails=$((fails + 1)); }
kept() { for f; do if [[ -e $f ]]; then pass "kept ${f#"$HOME"/}"; else fail "deleted ${f#"$HOME"/}"; fi; done; }
gone() { for f; do if [[ ! -e $f ]]; then pass "removed ${f#"$HOME"/}"; else fail "still there ${f#"$HOME"/}"; fi; done; }
code() { # expected_exit description command...
  local want=$1 what=$2 got=0
  shift 2
  "$@" >/dev/null 2>&1 || got=$?
  if ((got == want)); then pass "$what (exit $got)"; else fail "$what: exit $got, expected $want"; fi
}

TASKS=(trash thumbnails devcaches jetbrains builds)

echo "# CLI"
code 0 "--help" "$broom" --help
code 0 "--version" "$broom" --version
code 2 "unknown option" "$broom" --bogus
code 2 "unknown command" "$broom" frobnicate
code 2 "unknown task" "$broom" clean nosuchtask
code 2 "bad --older-than" "$broom" clean -n -d abc trash
code 2 "builds path must exist" "$broom" clean -n -p "$tmp/nope" builds

echo "# dry run changes nothing"
"$broom" -q clean -n -p "$P" "${TASKS[@]}" >"$tmp/dry.log"
kept "$D/Trash/files/junk.txt" "$C/thumbnails/large/old.png" "$C/pip/http/blob" \
  "$C/JetBrains/PyCharm2025.2" "$P/rusty/target" "$P/web/node_modules" "$P/py/.venv"
if [[ ! -e $tmp/calls ]]; then pass "no tool was called"; else fail "tools called: $(cat "$tmp/calls")"; fi
if grep -q 'would run: rm -rf -- .*rusty/target' "$tmp/dry.log"; then pass "dry run lists the commands"; else fail "dry run output"; fi

echo "# clean"
"$broom" -q clean -y -p "$P" "${TASKS[@]}" >"$tmp/run.log"
gone "$D/Trash/files/junk.txt" "$D/Trash/info/junk.txt.trashinfo" "$C/thumbnails/large/old.png" \
  "$C/pip/http/blob" "$C/JetBrains/PyCharm2025.2" "$D/JetBrains/IntelliJIdea2024.3" \
  "$P/rusty/target" "$P/web/node_modules" "$P/py/.venv"
kept "$D/Trash/files" "$C/thumbnails/large/new.png" "$C/pip" "$C/JetBrains/PyCharm2025.10" \
  "$D/JetBrains/IntelliJIdea2025.1" "$P/rusty/Cargo.toml" "$P/fresh/target" "$P/active/.venv" \
  "$P/notrust/target" "$P/.hidden/target"
if grep -q '^uv cache prune' "$tmp/calls" && grep -q '^conda clean --all -y' "$tmp/calls"; then pass "uv and conda (stubs) pruned"; else fail "devcache tools not called: $(cat "$tmp/calls")"; fi

echo "# update"
: >"$tmp/calls"
"$broom" -q update -n pipx >/dev/null
if ! grep -q pipx "$tmp/calls"; then pass "update -n runs nothing"; else fail "update -n ran pipx"; fi
"$broom" -q update -y pipx >/dev/null
if grep -q '^pipx upgrade-all' "$tmp/calls"; then pass "update -y runs pipx upgrade-all"; else fail "pipx not upgraded"; fi

echo "# dupes"
mkdir -p "$tmp/d/a" "$tmp/d/b"
head -c 2048 /dev/urandom >"$tmp/d/a/one.bin"
cp "$tmp/d/a/one.bin" "$tmp/d/b/two.bin"
head -c 2048 /dev/urandom >"$tmp/d/b/other.bin"
ln "$tmp/d/a/one.bin" "$tmp/d/a/hardlink.bin"
"$broom" -q dupes "$tmp/d" --min-size 1K >"$tmp/dupes.log"
if grep -q '1 group(s)' "$tmp/dupes.log" && ! grep -q other.bin "$tmp/dupes.log"; then
  pass "dupes finds the copy, ignores hardlinks and different files"
else
  fail "dupes output:"; cat "$tmp/dupes.log"
fi

echo
if ((fails)); then echo "$fails test(s) failed"; exit 1; fi
echo "all tests passed"
