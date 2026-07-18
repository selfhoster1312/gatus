#! /usr/bin/env bash

# Add new branches to pick in branches.cherry-pick
# Start rebase with `./rebase.sh`
# When there are conflicts, you will need to resolve them manually
# then run `./rebase --continue`

set -o pipefail

echo "Updating fork remote"
# git fetch fork

echo "Updating origin remote"
# git fetch origin

MASTER="$(git log origin/master --oneline | head -n 1 | awk '{print $1;}')"
echo "Last upstream commit on master: $MASTER"

MISSING_REBASE=0
TO_REBASE=()

while read -r branch; do
  echo "Examining branch $branch"
  BRANCH_BASE="$(git log fork/$branch --oneline | head -n 2 | sed -n '2p' | awk '{print $1;}')"
  if [[ "$BRANCH_BASE" != "$MASTER" ]]; then
    MISSING_REBASE=1
    TO_REBASE+=($branch)
  fi
done < branches.cherry-pick

if [ $MISSING_REBASE -eq 1 ]; then
  echo "ERROR: Some branches need to be rebased on upstream master:"
  for branch in "${TO_REBASE[@]}"; do
    echo "  - $branch"
  done
  exit 1
fi

if [[ "$1" != "--continue" ]]; then
  echo -n "" > /tmp/TMP_REBASE_GATUS
  rm -f /tmp/TMP_REBASE_GATUS_CONFLICT
else
  if [ -f /tmp/TMP_REBASE_GATUS_CONFLICT ]; then
    # Conflict solved
    cat /tmp/TMP_REBASE_GATUS_CONFLICT >> /tmp/TMP_REBASE_GATUS
  else
    # Logic problem
    echo "No current conflict. Nothing to do. Run without --continue maybe?"
    exit 0
  fi
fi

while read -r branch; do
  if [[ "$1" = "--continue" ]]; then
    if grep -P "^$branch\$" /tmp/TMP_REBASE_GATUS; then
      echo "Branch $branch already cherry-picked"
      continue
    fi
  fi
  
  if [[ "$LOCAL" = "" ]]; then
    remote_branch=fork/$branch
  else
    remote_branch=$branch
  fi
  echo "Cherry-picking commits from $remote_branch"
  if ! git cherry-pick $(git merge-base origin/master $remote_branch)..$remote_branch; then
    echo -n "$branch" > /tmp/TMP_REBASE_GATUS_CONFLICT
    echo "FIX CONFLICTS THEN CONTINUE:"
    echo "  - edit files to remove conflicts"
    echo "  - git add the files"
    echo "  - git cherry-pick --continue"
    echo "  - ./rebase --continue"
    exit 1
  fi

  echo "$branch" >> /tmp/TMP_REBASE_GATUS
  
done < branches.cherry-pick
