#!/bin/sh

export PS4="################################################################################ "

set -e
set -x
{ # Execute in a block that feeds stderr to stdout to avoid interleaving
  # Remind users that a PAT will be needed for pushing the commit.
  if [ "$INPUT_MY_GITHUB_SECRET_PAT" ]; then
    echo "GITHUB_SECRET_PAT = $INPUT_MY_GITHUB_SECRET_PAT"
  else
    echo "Required argument 'github_secret_pat' missing!"
    echo "Please review your GitHub Actions script that called this Action."
    exit 1
  fi

  # Construct path to private repo
  PRIVATE_REPO_DIR="$(realpath "$GITHUB_WORKSPACE/$INPUT_MY_PRIVATE_SUBDIR")"
  if [ ! -d "$PRIVATE_REPO_DIR" ]; then
    echo "Could not find the directory containing the private repo: $PRIVATE_REPO_DIR"
    exit 2
  fi

  if [ -z "$INPUT_SOURCE_FILE" ]
  then
    echo "Source file must be defined"
    return 1
  fi

  if [ -z "$INPUT_GIT_SERVER" ]
  then
    INPUT_GIT_SERVER="github.com"
  fi

  if [ -z "$INPUT_DESTINATION_BRANCH" ]
  then
    INPUT_DESTINATION_BRANCH=main
  fi
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"

  CLONE_DIR=$(mktemp -d)

  echo "Cloning destination git repository"
  git config --global user.email "$INPUT_USER_EMAIL"
  git config --global user.name "$INPUT_USER_NAME"
  git clone --single-branch --branch $INPUT_DESTINATION_BRANCH "https://x-access-token:$INPUT_MY_GITHUB_SECRET_PAT@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

  if [ ! -z "$INPUT_RENAME" ]
  then
    echo "Setting new filename: ${INPUT_RENAME}"
    DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER/$INPUT_RENAME"
  else
    DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
  fi

  echo "Showing cwd contents"
  ls -la .

  echo "Copying contents to git repo"
  mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER
  if [ -z "$INPUT_USE_RSYNC" ]
  then
    cp -R "$INPUT_SOURCE_FILE" "$DEST_COPY"
  else
    echo "rsync mode detected"
    rsync -avrh "$INPUT_SOURCE_FILE" "$DEST_COPY"
  fi

  cd "$CLONE_DIR"
  date > "$CLONE_DIR/force_commit.txt"

  if [ ! -z "$INPUT_DESTINATION_BRANCH_CREATE" ]
  then
    echo "Creating new branch: ${INPUT_DESTINATION_BRANCH_CREATE}"
    git checkout -b "$INPUT_DESTINATION_BRANCH_CREATE"
    OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH_CREATE"
  fi

  if [ -z "$INPUT_COMMIT_MESSAGE" ]
  then
    INPUT_COMMIT_MESSAGE="Update from https://$INPUT_GIT_SERVER/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
  fi

  echo "Adding git commit"
  git add .
  if git status | grep -q "Changes to be committed"
  then
    git commit --message "$INPUT_COMMIT_MESSAGE"
    echo "Pushing git commit"
    git push -u origin HEAD:"$OUTPUT_BRANCH"
  else
    echo "No changes detected"
  fi
} 2>&1
