#!/usr/bin/env bash
# ~/dotfiles/scripts/setup-folders.sh - Create development and document folder structure

create_home_structure() {
    echo "    Creating home folder structure..."

    local dirs=(
        "$HOME/code/personal"
        "$HOME/code/work"
        "$HOME/code/forks"
        "$HOME/code/spikes"
        "$HOME/code/archive"
        "$HOME/Documents/notes"
        "$HOME/Documents/books"
        "$HOME/Documents/papers"
        "$HOME/Documents/personal"
        "$HOME/bin"
        "$HOME/.config"
        "$HOME/.local/bin"
        "$HOME/.local/share"
        "$HOME/.local/state"
        "$HOME/Pictures/screenshots"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "      ✓ Created: $dir"
        fi
    done
}

# Main execution
create_home_structure