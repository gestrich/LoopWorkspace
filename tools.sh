#!/bin/bash

set -e
set -u

export TEAM_ID="5K844XFC6W"
export BUNDLE_ID="com.$TEAM_ID.loopkit.Loop"
export WORKSPACE_NAME="LoopWorkspace.xcworkspace"
export SCHEME_NAME="LoopWorkspace"

function archive(){
  ../tools.sh archive
}

function exportAll(){
  ../tools.sh exportAll
}

function appCenterUploads {
  ../tools.sh appCenterUploads
}

function runAll(){
  ../tools runAll
}

# Check if the function exists
if [ $# -gt 0 ]; then 
#if declare -f "$1" > /dev/null
  # call arguments verbatim
  "$@"
else
  # Show a helpful error
  echo "Functions Available:"
  typeset -f | awk '!/^main[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
  exit 1
fi
