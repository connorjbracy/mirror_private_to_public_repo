#!/bin/sh

sectionheader() {
  echo "################################################################################ $1"
}

statementheader() {
  echo "######################################## $1"
}

longecho() {
  echo "$1" | sed -r 's|^ *||' | sed -r 's|\\t|    |g'
}

printcmd() {
  # stderr > stdout for deterministic print statments
  { statementheader "$@"; set -x; "$@"; } 2>&1
  { set +x;       } 2>/dev/null
}

statementheader "Check for GitHub Secrets PAT"
# Remind users that a PAT will be needed for pushing the commit.
if [ "$INPUT_MY_GITHUB_SECRET_PAT" ]; then
  echo "GITHUB_SECRET_PAT = $INPUT_MY_GITHUB_SECRET_PAT"
else
  longecho "Required argument 'github_secret_pat' missing!
            Please review your GitHub Actions script that called this Action."
  exit 1
fi

# Construct path to private repo
PRIVATE_REPO_DIR="$(realpath "$GITHUB_WORKSPACE/$INPUT_MY_PRIVATE_SUBDIR")"
if [ ! -d "$PRIVATE_REPO_DIR" ]; then
  echo "Could not find the directory containing the private repo: $PRIVATE_REPO_DIR"
  exit 2
fi
# TODO: Resolve why GitHub Actions doesn't do this properly...
# PRIVATE_REPO_GIT_CONFIG_FULLNAME="$(                        \
#   git -C "$PRIVATE_REPO_DIR" config --get remote.origin.url \
#   | sed -nr 's|^.*github\.com[:/](\w+/\w+)(\.git)?$|\1|p'   \
# )"
# if [ "$PRIVATE_REPO_GIT_CONFIG_FULLNAME" != "$GITHUB_REPOSITORY" ]; then
#   longecho "Using the given argument
#     \t'private_subdir': $INPUT_MY_PRIVATE_SUBDIR
#     we were unable to find a directory corresponding to the expected
#     github repository:
#     \t'github.repository': $GITHUB_REPOSITORY
#     Instead, we found:
#     \t$ git -C \"$PRIVATE_REPO_DIR\" config --get remote.origin.url=$(git -C "$PRIVATE_REPO_DIR" config --get remote.origin.url)
#     \t> \$PRIVATE_REPO_GIT_CONFIG_FULLNAME=$PRIVATE_REPO_GIT_CONFIG_FULLNAME"
#   exit 3
# fi

INPUT_MY_GIT_SERVER=${INPUT_MY_GIT_SERVER:-"github.com"}

CLONE_DIR=$(mktemp -d)

# echo "Cloning destination git repository"
sectionheader "Cloning public repo to tempdir = $CLONE_DIR"
git config --global user.email "$INPUT_MY_USER_EMAIL"
git config --global user.name "$INPUT_MY_USER_NAME"
git clone "https://x-access-token:$INPUT_MY_GITHUB_SECRET_PAT@$INPUT_MY_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
# git -C "$CLONE_DIR" fetch --all

sectionheader "Copying contents to git repo"
################################################################################
echo "INPUT_MY_PUBLIC_GITIGNORE_FILENAME_CONVENTION = $INPUT_MY_PUBLIC_GITIGNORE_FILENAME_CONVENTION"
PUBLIC_REPO_DIR=$CLONE_DIR
PUBLIC_GITIGNORE_FILE="$PUBLIC_REPO_DIR/.gitignore"
TMP_GITIGNORE_FILE="./.gitignore"
echo "PUBLIC_GITIGNORE_FILE = $PUBLIC_GITIGNORE_FILE"
find "$PRIVATE_REPO_DIR" -name "$INPUT_MY_PUBLIC_GITIGNORE_FILENAME_CONVENTION" \
| while read -r f
do
  # printcmd echo "File: $f"
  # printcmd sed -nr "s|^([^#].+)$|${f}/\1|p" < "$f"
  # printcmd basename "$f"
  # 1) Removed comment/blank lines from source ".gitignore" files
  # 2) Strip out paths to make entries relative to public repo base directory
  # 3) Dump entries into $PUBLIC_REPO/.gitignore
  sed -nr "s|^([^#].+)$|${f}/\1|p"                                   \
  < "$f"                                                             \
  | sed -r "s|^$PRIVATE_REPO_DIR/(.+/)?$(basename "$f")/(.+)$|\1\2|" \
  >> "$TMP_GITIGNORE_FILE"
done
# Remove redundancies created by running this script more than once (which will
# happen over time). Doing this, rather than starting a fresh file, allows for a
# .gitignore to exist in the public repo without cluttering it (rather than
# having to generate one each time, the lifetime of which would be the duration
# of this run)
cat "$PUBLIC_GITIGNORE_FILE" >> "$TMP_GITIGNORE_FILE"
cat "$TMP_GITIGNORE_FILE" | sort | uniq > "$PUBLIC_GITIGNORE_FILE"
printcmd cat "$PUBLIC_GITIGNORE_FILE"
printcmd git -C "$PUBLIC_REPO_DIR" status
printcmd rsync -va --exclude-from="$PUBLIC_GITIGNORE_FILE" "$PRIVATE_REPO_DIR/" "$PUBLIC_REPO_DIR"
printcmd git config --global --add safe.directory "$PUBLIC_REPO_DIR"
# statementheader "Printing ownership info of /tmp"
# PUBLIC_REPO_PARENT=$(realpath "$PUBLIC_REPO_DIR/..")
# ls -la "$PUBLIC_REPO_PARENT"
# statementheader "Printing ownership info of public/"
# ls -la "$PUBLIC_REPO_DIR"
# statementheader "Printing ownership info of public/private"
# ls -la "$PUBLIC_REPO_DIR/private"
################################################################################


sectionheader "Changing to public clone dir"
printcmd cd "$CLONE_DIR"
sectionheader "Copying date to file to force commit"
printcmd date > "$CLONE_DIR/force_commit.txt"



# printcmd git fetch --all
# printcmd git branch -a
WORKING_BRANCH_NAME=${INPUTS_MY_WORKING_BRANCH_NAME:-"$GITHUB_HEAD_REF"}
PUBLIC_ORIGIN_BRANCH_NAME="origin/$WORKING_BRANCH_NAME"
PUBLIC_REMOTE_ORIGIN_BRANCH_NAME="remotes/$PUBLIC_ORIGIN_BRANCH_NAME"
statementheader "Looking for '$WORKING_BRANCH_NAME' in origin"
PUBLIC_ORIGIN_HEAD_REF="$(                                       \
  git branch -a                                                  \
  | sed -nr "s|^\s*($PUBLIC_REMOTE_ORIGIN_BRANCH_NAME)\s*$|\1|p" \
)"
if [ "$PUBLIC_ORIGIN_HEAD_REF" ]; then
  echo "Found $PUBLIC_ORIGIN_HEAD_REF, pushing to existing branch!"
  git switch -c "$WORKING_BRANCH_NAME" "$PUBLIC_ORIGIN_HEAD_REF"
else
  echo "Did not find $PUBLIC_ORIGIN_BRANCH_NAME, starting a new branch!"
  git checkout -b "$WORKING_BRANCH_NAME"
fi



# sectionheader "Check for INPUT_DESTINATION_BRANCH_CREATE = $INPUT_DESTINATION_BRANCH_CREATE"
# if [ ! -z "$INPUT_DESTINATION_BRANCH_CREATE" ]; then
#   echo "Creating new branch: ${INPUT_DESTINATION_BRANCH_CREATE}"
#   git checkout -b "$INPUT_DESTINATION_BRANCH_CREATE"
#   OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH_CREATE"
# fi
# sectionheader "Concluded OUTPUT_BRANCH = $OUTPUT_BRANCH"

sectionheader "Check for INPUT_COMMIT_MESSAGE = $INPUT_MY_COMMIT_MESSAGE"
if [ -z "$INPUT_MY_COMMIT_MESSAGE" ]; then
  INPUT_MY_COMMIT_MESSAGE="Update from https://$INPUT_MY_GIT_SERVER/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
fi

sectionheader "Adding git commit"
printcmd git add .
if git status | grep -q "Changes to be committed"; then
  printcmd git commit --message "$INPUT_MY_COMMIT_MESSAGE"
  echo "Pushing git commit"
  printcmd git push -u origin HEAD:"$GITHUB_HEAD_REF"
else
  echo "No changes detected"
fi
