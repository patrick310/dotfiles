# ~/.config/blesh/init.sh - ble.sh configuration

# Load system bash_completion before fzf integrations (required for combined usage)
if [ -r /etc/profile.d/bash_completion.sh ]; then
  source /etc/profile.d/bash_completion.sh
fi

# Delay fzf integration loading so prompt appears quickly
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
