#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backend_dir="$(cd -- "$script_dir/.." && pwd)"
compose_file="$backend_dir/compose.prod.yml"
compose_json="$(docker compose -f "$compose_file" config --format json)"

BACKEND_DIR="$backend_dir" COMPOSE_JSON="$compose_json" python3 - <<'PY'
import json
import os
import sys

backend_dir = os.environ["BACKEND_DIR"]
compose = json.loads(os.environ["COMPOSE_JSON"])
services = compose.get("services", {})
required = {
    "api": {
        "context": backend_dir,
        "dockerfile": "docker/api.Dockerfile",
    },
    "worker": {
        "context": backend_dir,
        "dockerfile": "docker/worker.Dockerfile",
    },
}

problems = []
for service_name, expected in required.items():
    service = services.get(service_name)
    if not service:
        problems.append(f"Missing service '{service_name}' in compose config")
        continue

    build = service.get("build")
    if not isinstance(build, dict):
        problems.append(
            f"Service '{service_name}' must define a local build block in compose.prod.yml"
        )
        continue

    context = build.get("context")
    dockerfile = build.get("dockerfile")
    if context != expected["context"]:
        problems.append(
            f"Service '{service_name}' build.context must be '{expected['context']}', got '{context}'"
        )
    if dockerfile != expected["dockerfile"]:
        problems.append(
            f"Service '{service_name}' build.dockerfile must be '{expected['dockerfile']}', got '{dockerfile}'"
        )

if problems:
    for problem in problems:
        print(problem, file=sys.stderr)
    raise SystemExit(1)

print("Validated production compose backend build wiring for api and worker.")
PY