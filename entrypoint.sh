#!/bin/sh

export PS4="################################################################################ "
# export PS4="$(awk '{if(NR==${LINENO} print length}') "

set -e
set -x

# printf -- '-%.0s' {1..80}
# echo 'Hello, World!'

printenv

if [[ "$INPUT_USER_EMAIL" ]]; then
  echo "USER_EMAIL = $INPUT_USER_EMAIL"
else
  echo "Required argument 'INPUT_USER_EMAIL' missing!"
  exit 1
fi


if [[ "$INPUT_USER_NAME" ]]; then
  echo "USER_NAME = $INPUT_USER_NAME"
else
  echo "Required argument 'INPUT_USER_NAME' missing!"
  exit 1
fi


if [[ "$INPUT_GITHUB_SECRET_PAT" ]]; then
  echo "GITHUB_SECRET_PAT = $INPUT_GITHUB_SECRET_PAT"
else
  echo "Required argument 'INPUT_GITHUB_SECRET_PAT' missing!"
  exit 1
fi


if [[ "$INPUT_GITHUB_WORKSPACE" ]]; then
  echo "GITHUB_WORKSPACE = $INPUT_GITHUB_WORKSPACE"
else
  echo "Required argument 'INPUT_GITHUB_WORKSPACE' missing!"
  exit 1
fi


if [[ "$INPUT_PUBLIC_GITIGNORE_NAME_PATTERN" ]]; then
  echo "PUBLIC_GITIGNORE_NAME_PATTERN = $INPUT_PUBLIC_GITIGNORE_NAME_PATTERN"
fi


if [[ "$INPUT_PRIVATE_DIR" ]]; then
  echo "PRIVATE_DIR = $INPUT_PRIVATE_DIR"
fi


if [[ "$INPUT_PUBLIC_DIR" ]]; then
  echo "PUBLIC_DIR = $INPUT_PUBLIC_DIR"
fi


if [[ "$INPUT_WORKING_BRANCH_NAME" ]]; then
  echo "WORKING_BRANCH_NAME = $INPUT_WORKING_BRANCH_NAME"
fi


if [[ "$INPUT_COMMIT_MESSAGE" ]]; then
  echo "COMMIT_MESSAGE = $INPUT_COMMIT_MESSAGE"
fi


if [[ "$INPUT_GIT_SERVER" ]]; then
  echo "GIT_SERVER = $INPUT_GIT_SERVER"
fi

pwd
ls -la .
ls -la /
ls -la ~/

# if [ -z "$INPUT_SOURCE_FILE" ]
# then
#   echo "Source file must be defined"
#   return 1
# fi

# if [ -z "$INPUT_GIT_SERVER" ]
# then
#   INPUT_GIT_SERVER="github.com"
# fi

# if [ -z "$INPUT_DESTINATION_BRANCH" ]
# then
#   INPUT_DESTINATION_BRANCH=main
# fi
# OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"

# CLONE_DIR=$(mktemp -d)

# echo "Cloning destination git repository"
# git config --global user.email "$INPUT_USER_EMAIL"
# git config --global user.name "$INPUT_USER_NAME"
# git clone --single-branch --branch $INPUT_DESTINATION_BRANCH "https://x-access-token:$INPUT_REPO_LEVEL_SEC@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

# if [ ! -z "$INPUT_RENAME" ]
# then
#   echo "Setting new filename: ${INPUT_RENAME}"
#   DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER/$INPUT_RENAME"
# else
#   DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
# fi

# echo "Copying contents to git repo"
# mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER
# if [ -z "$INPUT_USE_RSYNC" ]
# then
#   cp -R "$INPUT_SOURCE_FILE" "$DEST_COPY"
# else
#   echo "rsync mode detected"
#   rsync -avrh "$INPUT_SOURCE_FILE" "$DEST_COPY"
# fi

# cd "$CLONE_DIR"

# if [ ! -z "$INPUT_DESTINATION_BRANCH_CREATE" ]
# then
#   echo "Creating new branch: ${INPUT_DESTINATION_BRANCH_CREATE}"
#   git checkout -b "$INPUT_DESTINATION_BRANCH_CREATE"
#   OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH_CREATE"
# fi

# if [ -z "$INPUT_COMMIT_MESSAGE" ]
# then
#   INPUT_COMMIT_MESSAGE="Update from https://$INPUT_GIT_SERVER/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
# fi

# echo "Adding git commit"
# git add .
# if git status | grep -q "Changes to be committed"
# then
#   git commit --message "$INPUT_COMMIT_MESSAGE"
#   echo "Pushing git commit"
#   git push -u origin HEAD:"$OUTPUT_BRANCH"
# else
#   echo "No changes detected"
# fi
# ################################################################################
# # if git status | grep -q "Changes to be committed"
# # then
# #   git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
# #   echo "Pushing git commit"
# #   git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
# #   echo "Creating a pull request"
# #   gh pr create -t $INPUT_DESTINATION_HEAD_BRANCH \
# #                -b $INPUT_DESTINATION_HEAD_BRANCH \
# #                -B $INPUT_DESTINATION_BASE_BRANCH \
# #                -H $INPUT_DESTINATION_HEAD_BRANCH \
# #                   $PULL_REQUEST_REVIEWERS
