#!/bin/sh

set -e
set -x

# echo "INPUT_REPO_LEVEL_SEC"
# echo $INPUT_REPO_LEVEL_SEC

# echo "printenv"
# printenv
# echo "printenv | grep API_TOKEN_GITHUB"
# printenv | grep -i "API_TOKEN_GITHUB"
# echo "printenv | grep API_TOKEN_GITHUB | wc -l"
# printenv | grep -i "API_TOKEN_GITHUB" | wc -l
# echo "printenv | grep secret"
# printenv | grep -i "secret"
# echo "printenv | grep secret | wc"
# printenv | grep -i "secret" | wc -l
# echo "printenv | grep action"
# printenv | grep -i "action"
# echo "printenv | grep action | wc"
# printenv | grep -i "action" | wc -l
# echo "printenv | grep TOKEN"
# printenv | grep -i "TOKEN"
# echo "printenv | grep TOKEN | wc"
# printenv | grep -i "TOKEN" | wc -l

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
git clone --single-branch --branch $INPUT_DESTINATION_BRANCH "https://x-access-token:$INPUT_REPO_LEVEL_SEC@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

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
################################################################################
# if git status | grep -q "Changes to be committed"
# then
#   git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
#   echo "Pushing git commit"
#   git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
#   echo "Creating a pull request"
#   gh pr create -t $INPUT_DESTINATION_HEAD_BRANCH \
#                -b $INPUT_DESTINATION_HEAD_BRANCH \
#                -B $INPUT_DESTINATION_BASE_BRANCH \
#                -H $INPUT_DESTINATION_HEAD_BRANCH \
#                   $PULL_REQUEST_REVIEWERS
