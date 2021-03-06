#!/bin/sh

sectionheader() {
  echo "################################################################################ $1"
}

statementheader() {
  echo "######################################## $1..."
}

longecho() {
  echo "$1" | sed -r 's|^ *||' | sed -r 's|\\t|    |g'
}

printcmd() {
  # stderr > stdout for deterministic print statments
  { statementheader "$@"; set -x; "$@"; } 2>&1
  { set +x;       } 2>/dev/null
}


################################################################################
####################### Construct/Validate Basic Inputs ########################
################################################################################
sectionheader "Construct/Validate Basic Inputs"
######################### Validate GitHub Secrets PAT ##########################
statementheader "Checking for GitHub Secrets PAT"
# Remind users that a PAT will be needed for pushing the commit.
if [ "$INPUT_GITHUB_SECRET_PAT" ]; then
  echo "GITHUB_SECRET_PAT = $INPUT_GITHUB_SECRET_PAT"
else
  longecho "Required argument 'github_secret_pat' missing!
            Please review your GitHub Actions script that called this Action."
  exit 1
fi

################# Construct and Validate Path to Private Repo ##################
statementheader "Checking path to private repo is what we expect"
# Construct path to private repo
PRIVATE_REPO_DIR="$(realpath "$GITHUB_WORKSPACE/$INPUT_PRIVATE_SUBDIR")"
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
#     \t'private_subdir': $INPUT_PRIVATE_SUBDIR
#     we were unable to find a directory corresponding to the expected
#     github repository:
#     \t'github.repository': $GITHUB_REPOSITORY
#     Instead, we found:
#     \t$ git -C \"$PRIVATE_REPO_DIR\" config --get remote.origin.url=$(git -C "$PRIVATE_REPO_DIR" config --get remote.origin.url)
#     \t> \$PRIVATE_REPO_GIT_CONFIG_FULLNAME=$PRIVATE_REPO_GIT_CONFIG_FULLNAME"
#   exit 3
# fi

################ Determine/Validate Name of Public Counterpart #################
statementheader "Determining/validating name of public counterpart"
if [ "$INPUT_PUBLIC_REPO" ]; then
  PUBLIC_REPO_FULLNAME="$INPUT_PUBLIC_REPO"
else
  statementheader "Automatically determining public repo name"
  PUBLIC_REPO_FULLNAME="$(            \
    echo "$GITHUB_REPOSITORY"         \
    | sed -nr 's|^(.+)_private$|\1|p' \
  )"
fi
echo "PUBLIC_REPO_FULLNAME = $PUBLIC_REPO_FULLNAME"
if [ ! "$PUBLIC_REPO_FULLNAME" ]; then
  longecho "We were not given a name for the public repo, nor could we
            automatically determine a suitable one from the private repo name.
            Please provide a public repo name through the 'public_repo'
            argument."
  exit 4
fi

################### Git Server Used for Cloning Public Repo ####################
statementheader "Setting GitHub server used for cloning public repo"
INPUT_GIT_SERVER=${INPUT_GIT_SERVER:-"github.com"}

########################### Construct Commit Message ###########################
statementheader "Constructing the commit message"
# Due to mismatch ownership of checkedout files (both GitHub Actions calling
# script and this script), git complains about certain operations unless we tell
# it we know that the private/public repo files can be trusted (there is an
# equivalent statement below for the private repo).
git config --global --add safe.directory "$PRIVATE_REPO_DIR"
echo "Check for INPUT_COMMIT_MESSAGE = $INPUT_COMMIT_MESSAGE"
if [ -z "$INPUT_COMMIT_MESSAGE" ]; then
  INPUT_COMMIT_MESSAGE="(from git log -1, likely not the user commit \
  message) - $(                                                         \
    git -C "$PRIVATE_REPO_DIR" log -1 --pretty=format:"%s"              \
  )"
fi
INPUT_COMMIT_MESSAGE="Update from https://$INPUT_GIT_SERVER/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}. Original commit message: \"$INPUT_COMMIT_MESSAGE\""


################################################################################
############################# Checkout Public Repo #############################
################################################################################
sectionheader "Checkout Public Repo"
######################## Clone Public Repo to a tmp Dir ########################
statementheader "Cloning public repo to tmp dir"
PUBLIC_REPO_DIR=$(mktemp -d)

# sectionheader "Cloning public repo to tempdir = $PUBLIC_REPO_DIR"
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"
git clone "https://x-access-token:$INPUT_GITHUB_SECRET_PAT@$INPUT_GIT_SERVER/$PUBLIC_REPO_FULLNAME.git" "$PUBLIC_REPO_DIR"

################### Find the Base Ref Branch in Public Repo ####################
statementheader "Determining if public repo has branch with private repo's branch name"
WORKING_BRANCH_NAME="${INPUT_WORKING_BRANCH_NAME:-"$GITHUB_HEAD_REF"}"
PUBLIC_ORIGIN_BRANCH_NAME="origin/$WORKING_BRANCH_NAME"
PUBLIC_REMOTE_ORIGIN_BRANCH_NAME="remotes/$PUBLIC_ORIGIN_BRANCH_NAME"
echo "Looking for '$WORKING_BRANCH_NAME' in origin..."
PUBLIC_ORIGIN_HEAD_REF="$(                                       \
  git -C "$PUBLIC_REPO_DIR" branch -a                            \
  | sed -nr "s|^\s*($PUBLIC_REMOTE_ORIGIN_BRANCH_NAME)\s*$|\1|p" \
)"
######## Checkout Existing Base Ref Branch or Create New with Same Name ########
if [ "$PUBLIC_ORIGIN_HEAD_REF" ]; then
  echo "Found $PUBLIC_ORIGIN_HEAD_REF, pushing to existing branch!"
  statementheader "Switching to public repo's branch"
  git -C "$PUBLIC_REPO_DIR"                                      \
      switch -c "$WORKING_BRANCH_NAME" "$PUBLIC_ORIGIN_HEAD_REF"
else
  echo "Did not find $PUBLIC_ORIGIN_BRANCH_NAME, starting a new branch!"
  statementheader "Creating a new branch for the public repo"
  git -C "$PUBLIC_REPO_DIR" checkout -b "$WORKING_BRANCH_NAME"
fi


################################################################################
#################### Copying Contents of Private to Public #####################
################################################################################
sectionheader "Copying Contents to Public Git Repo"
####### Aggregate the Pseudo ".gitignore" Files from Private into Public #######
statementheader "Aggregating pseudo '.gitignore' files to 'public/.gitignore'"
PUBLIC_GITIGNORE_FILE="$PUBLIC_REPO_DIR/.gitignore"
TMP_GITIGNORE_FILE="$GITHUB_WORKSPACE/.gitignore"
echo "Aggregating private/*/$INPUT_PSEUDO_GITIGNORE_FILENAME->public/.gitignore"
find "$PRIVATE_REPO_DIR" -name "$INPUT_PSEUDO_GITIGNORE_FILENAME" \
| while read -r f; do
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
############# Copy the Non-ignored Files from Private into Public ##############
statementheader "Copying files from private to public, ignoring files listed in 'public/.gitignore'"
printcmd rsync -va --exclude-from="$PUBLIC_GITIGNORE_FILE" "$PRIVATE_REPO_DIR/" "$PUBLIC_REPO_DIR"
# Again, tell git that our public repo is to be trusted
# NOTE: Seemingly, this command should be run after any modifications to the
#       contents of the repo directory (likely as it indexes the files at the
#       time of the call)
git config --global --add safe.directory "$PUBLIC_REPO_DIR"


################################################################################
################# Commit the Private Changes to Public Origin ##################
################################################################################
sectionheader "Committing the Private Changes to Public Origin"
statementheader "Changing to public clone dir"
printcmd cd "$PUBLIC_REPO_DIR"

statementheader "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"; then
  git commit --message "$INPUT_COMMIT_MESSAGE"
  sectionheader "Pushing git commit"
  git push -u origin HEAD:"$GITHUB_HEAD_REF"
else
  echo "No changes detected"
fi
