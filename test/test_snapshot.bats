#!/usr/bin/env bats

setup() {
  # Create a fresh temporary Git repo
  export TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  git init >/dev/null

  # Add dummy files
  printf '%s\n' '#!/usr/bin/env bash' 'echo hello' > foo.sh
  printf '%s\n' 'body text' > README.md
  printf '%s\n' 'FROM alpine' > Dockerfile
  mkdir sub && printf 'content' > sub/config.yml
  git add . >/dev/null
  git commit -m "initial" >/dev/null

  # Prepare a fake bin directory for stubbing
  mkdir -p bin

  # Symlink the snapshot script under test
  ln -s "${BATS_TEST_DIRNAME}/../src/snapshot.sh" bin/snapshot

  # Stub `tree` to simply echo each input filename
  cat > bin/tree << 'EOF'
#!/usr/bin/env bash
while read -r f; do
  echo "$f"
done
EOF
  chmod +x bin/tree

  # Stub `pbcopy` to capture clipboard output
  cat > bin/pbcopy << 'EOF'
#!/usr/bin/env bash
cat >"$TMPDIR/clip"
EOF
  chmod +x bin/pbcopy

  # Ensure our fake bin comes first in PATH
  export PATH="$TMPDIR/bin:$PATH"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "snapshot tree lists all tracked files" {
  run snapshot tree
  [ "$status" -eq 0 ]
  [[ "${lines[@]}" =~ "foo.sh" ]]
  [[ "${lines[@]}" =~ "README.md" ]]
  [[ "${lines[@]}" =~ "Dockerfile" ]]
  [[ "${lines[@]}" =~ "sub/config.yml" ]]
}

@test "snapshot code dumps code/config files with headers" {
  run snapshot code
  [ "$status" -eq 0 ]
  [[ "$output" =~ "===== foo.sh =====" ]]
  [[ "$output" =~ "echo hello" ]]
  [[ "$output" =~ "===== sub/config.yml =====" ]]
  [[ "$output" =~ "content" ]]
}

@test "snapshot copy sends dump to pbcopy" {
  run snapshot copy
  [ "$status" -eq 0 ]
  [ -s "$TMPDIR/clip" ]
  grep -q "===== foo.sh =====" "$TMPDIR/clip"
}
