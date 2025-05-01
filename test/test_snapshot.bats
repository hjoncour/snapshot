#!/usr/bin/env bats

# Setup a temporary Git repo before each test
setup() {
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  git init >/dev/null
  # create some dummy files
  printf '%s\n' '#!/usr/bin/env bash' 'echo hello' > foo.sh
  printf '%s\n' 'body text' > README.md
  printf '%s\n' 'FROM alpine' > Dockerfile
  mkdir sub && printf 'content' > sub/config.yml
  git add . >/dev/null
  git commit -m "initial" >/dev/null

  # symlink your snapshot script into PATH
  export PATH="$TMPDIR/bin:$PWD/../src:$PATH"
  mkdir -p bin
  ln -s "$PWD/../src/snapshot.sh" bin/snapshot
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "snapshot tree lists all tracked files" {
  run snapshot tree
  [ "$status" -eq 0 ]
  # should contain our four files
  [[ "${lines[@]}" =~ "foo.sh" ]]
  [[ "${lines[@]}" =~ "README.md" ]]
  [[ "${lines[@]}" =~ "Dockerfile" ]]
  [[ "${lines[@]}" =~ "sub/config.yml" ]]
}

@test "snapshot code dumps code/config files with headers" {
  run snapshot code
  [ "$status" -eq 0 ]
  # the header lines and contents
  [[ "${output}" =~ "===== foo.sh =====" ]]
  [[ "${output}" =~ "echo hello" ]]
  [[ "${output}" =~ "===== sub/config.yml =====" ]]
  [[ "${output}" =~ "content" ]]
}

@test "snapshot copy sends dump to pbcopy" {
  # stub pbcopy to capture input
  pbcopy() { cat >"$TMPDIR/clip"; }
  export -f pbcopy

  run snapshot copy
  [ "$status" -eq 0 ]
  [ -s "$TMPDIR/clip" ]
  # ensure the clip contains a header
  grep -q "===== foo.sh =====" "$TMPDIR/clip"
}
