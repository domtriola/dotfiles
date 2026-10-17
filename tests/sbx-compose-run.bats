#!/usr/bin/env bats
#
# sbx-compose-run, through its command line.

load helpers

setup() {
  common_setup
  sbx_compose_run="$repo_root/env/.local/bin/sbx-compose-run"
  : >"$FAKE_STATE/docker.log"
  : >"$FAKE_STATE/sudo.log"
  project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project/src"
  git -C "$project" init --quiet
  printf 'services:\n  app:\n    image: alpine\n' >"$project/compose.yaml"
  cd "$project/src"
}

@test "it prints only the command's output, and runs it from the project root" {
  FAKE_DOCKER_RUN='echo hello; pwd' run "$sbx_compose_run" app echo hello
  [ "$status" -eq 0 ]
  [ "$output" = "hello
$project" ]
  [ "$(cat "$FAKE_STATE/docker.log")" = "compose --progress quiet run --rm --no-deps app echo hello" ]
}

@test "it exits with the command's exit code" {
  FAKE_DOCKER_RUN='exit 3' run "$sbx_compose_run" app false
  [ "$status" -eq 3 ]
}

@test "it gives the files that the run created or changed back to the sandbox user" {
  echo old >"$project/tracked.txt"
  echo same >"$project/clean.txt"
  git -C "$project" add tracked.txt clean.txt compose.yaml
  git -C "$project" -c user.name=t -c user.email=t@t commit --quiet -m init
  FAKE_DOCKER_RUN='echo new >tracked.txt; mkdir -p out/deep; echo x >"out/deep/a file.txt"' \
    run "$sbx_compose_run" app build
  [ "$status" -eq 0 ]
  me="$(id -u):$(id -g)"
  [ "$(cat "$FAKE_STATE/sudo.log")" = "chown -h $me -- out out/deep out/deep/a file.txt tracked.txt" ]
}

@test "a run that changes nothing calls no sudo" {
  git -C "$project" add compose.yaml
  git -C "$project" -c user.name=t -c user.email=t@t commit --quiet -m init
  run "$sbx_compose_run" app true
  [ "$status" -eq 0 ]
  [ ! -s "$FAKE_STATE/sudo.log" ]
}

@test "a failed command still gives the files back, and keeps its exit code" {
  FAKE_DOCKER_RUN='echo x >made.txt; exit 2' run "$sbx_compose_run" app build
  [ "$status" -eq 2 ]
  [[ "$(cat "$FAKE_STATE/sudo.log")" == *" made.txt"* ]]
}

@test "a project with no Compose file fails with a clear message, and runs nothing" {
  rm "$project/compose.yaml"
  run "$sbx_compose_run" app true
  [ "$status" -eq 1 ]
  [ "$output" = "sbx-compose-run: no Compose file in $project (compose.yaml, compose.yml, docker-compose.yaml or docker-compose.yml)" ]
  [ ! -s "$FAKE_STATE/docker.log" ]
}

@test "COMPOSE_FILE names a Compose file in another place" {
  rm "$project/compose.yaml"
  COMPOSE_FILE=other.yaml run "$sbx_compose_run" app true
  [ "$status" -eq 0 ]
  [ -s "$FAKE_STATE/docker.log" ]
}

@test "--deps keeps the service's dependencies" {
  run "$sbx_compose_run" --deps app migrate
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/docker.log")" = "compose --progress quiet run --rm app migrate" ]
}

@test "flags before -- go to docker compose run" {
  run "$sbx_compose_run" --deps -e FOO=1 app -- npm test -- --grep x
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/docker.log")" = "compose --progress quiet run --rm -e FOO=1 app npm test -- --grep x" ]
}

@test "without flags, a -- in the command stays in the command" {
  run "$sbx_compose_run" app npm test -- --grep x
  [ "$(cat "$FAKE_STATE/docker.log")" = "compose --progress quiet run --rm --no-deps app npm test -- --grep x" ]
}

@test "a -- right after the service is dropped" {
  run "$sbx_compose_run" app -- npm test
  [ "$(cat "$FAKE_STATE/docker.log")" = "compose --progress quiet run --rm --no-deps app npm test" ]
}

@test "flags without -- are a usage error" {
  run "$sbx_compose_run" -e FOO=1 app npm test
  [ "$status" -eq 1 ]
  [[ "$output" == "sbx-compose-run: "*" -- "* ]]
  [ ! -s "$FAKE_STATE/docker.log" ]
}

@test "a service with no command is a usage error" {
  run "$sbx_compose_run" app
  [ "$status" -eq 1 ]
  [[ "$output" == "sbx-compose-run: name a service and a command. Run sbx-compose-run --help." ]]
  [ ! -s "$FAKE_STATE/docker.log" ]
}

@test "--help explains the command" {
  run "$sbx_compose_run" --help
  [ "$status" -eq 0 ]
  [[ "$output" == "Usage:"* ]]
  [[ "$output" == *"--deps"* ]]
  [[ "$output" == *"chown"* ]]
  [ ! -s "$FAKE_STATE/docker.log" ]
}
