#!/usr/bin/env bash
# Forward OmniWM workspace/window/focus events to SketchyBar as a single custom
# trigger, so the workspace pills in items/spaces.lua update instantly instead of
# waiting for the 2s poll backstop. Requires OmniWM IPC to be enabled
# (menu bar -> Enable IPC).
#
# Idempotent: any previously-running watcher is killed before a new one starts,
# so re-running this (e.g. on every SketchyBar reload) never stacks duplicates.

OMNIWMCTL=/opt/homebrew/bin/omniwmctl
SKETCHYBAR=/opt/homebrew/bin/sketchybar

pkill -f "omniwmctl watch active-workspace" 2>/dev/null

# --exec runs once per event; we don't need the event payload, just the nudge.
exec "$OMNIWMCTL" watch active-workspace,windows-changed,focus \
	--exec "$SKETCHYBAR" --trigger omniwm_workspace_change
