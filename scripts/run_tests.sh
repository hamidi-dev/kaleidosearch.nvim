#!/bin/bash

# Ensure we're in the plugin root directory
cd "$(dirname "$0")/.." || exit

# Check for Plenary in common locations
PLENARY_PATHS=(
  "$HOME/.local/share/nvim/lazy/plenary.nvim"
  "$HOME/.local/share/nvim/site/pack/vendor/start/plenary.nvim"
  "$HOME/.local/share/nvim/site/pack/packer/start/plenary.nvim"
  "$HOME/.local/share/nvim/plugged/plenary.nvim"
)

PLENARY_FOUND=false
for path in "${PLENARY_PATHS[@]}"; do
  if [ -d "$path" ]; then
    echo "Found Plenary at: $path"
    PLENARY_FOUND=true
    break
  fi
done

if [ "$PLENARY_FOUND" = false ]; then
  echo "Installing Plenary.nvim..."
  mkdir -p "$HOME/.local/share/nvim/site/pack/vendor/start"
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$HOME/.local/share/nvim/site/pack/vendor/start/plenary.nvim"
fi

# Run the tests using Lua directly to avoid command not found issues
nvim --headless --noplugin -u test/minimal_init.lua -c "lua require('plenary.busted').run('test/kaleidosearch_spec.lua')" -c "qa!"

