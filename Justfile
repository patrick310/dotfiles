set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: bootstrap

bootstrap profile="desktop":
    ./bootstrap.sh --profile {{profile}}

bootstrap-force profile="desktop":
    ./bootstrap.sh --profile {{profile}} --force

bootstrap-dry-run profile="desktop":
    ./bootstrap.sh --profile {{profile}} --dry-run

stow package:
    @echo "Stowing {{package}}"
    stow {{package}}

restow package:
    @echo "Restowing {{package}}"
    stow --restow {{package}}

install-packages os profile="desktop":
    ./install/{{os}}.sh {{profile}}

check profile="desktop":
    @if command -v shellcheck >/dev/null; then \
        echo "Running shellcheck..."; \
        shellcheck bootstrap.sh lib/*.sh scripts/*.sh install/*.sh; \
    else \
        echo "shellcheck not installed. Skipping lint step." >&2; \
    fi
    @echo "Simulating stow for all packages..."
    pkgs=$(find . -maxdepth 2 -type f -name '.stow' -printf '%h\\n' | xargs -r -n1 basename | sort -u)
    if [ -n "$pkgs" ]; then \
        for pkg in $pkgs; do \
            echo "  -> $pkg"; \
            stow --dir "$PWD" --target "$HOME" --no --verbose=0 "$pkg" >/dev/null || true; \
        done; \
    else \
        echo "  (no packages found)"; \
    fi
    ./scripts/check-packages.sh {{profile}}
