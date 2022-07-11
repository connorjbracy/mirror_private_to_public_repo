#!/bin/sh

export PS4="################################################################################ "

set -e
set -x
{ # Execute in a block that feeds stderr to stdout to avoid interleaving

  ####################################################### TODO: DEBUG STATEMENTS
  printenv
  ####################################################### TODO: DEBUG STATEMENTS

  # Remind users that a PAT will be needed for pushing the commit.
  if [ "$INPUT_GITHUB_SECRET_PAT" ]; then
    echo "GITHUB_SECRET_PAT = $INPUT_GITHUB_SECRET_PAT"
  else
    echo "Required argument 'github_secret_pat' missing!"
    echo "Please review your GitHub Actions script that called this Action."
    exit 1
  fi


  echo "INPUT_PUBLIC_GITIGNORE_FILENAME_CONVENTION = $INPUT_PUBLIC_GITIGNORE_FILENAME_CONVENTION"

  # Construct path to private repo
  PRIVATE_REPO_DIR="$GITHUB_WORKSPACE/$INPUT_PRIVATE_SUBDIR"
  if [ ! -d "$PRIVATE_REPO_DIR" ]; then
    echo "Could not find the directory containing the private repo: $PRIVATE_REPO_DIR"
    exit 2
  fi

  # # Construct path to public repo
  # PUBLIC_REPO_DIR="$GITHUB_WORKSPACE/$INPUT_PUBLIC_SUBDIR"
  # if [ -d "$PUBLIC_REPO_DIR" ]; then
  #   echo "Found another directory where we intend to clone the public repo: $PUBLIC_REPO_DIR"
  #   echo "Please specify an empty/nonexistent directory for us to use for the public repo."
  #   exit 2
  # fi
  if [ "$INPUT_DESTINATION_REPO" ]; then
    PUBLIC_REPO_FULLNAME="$INPUT_DESTINATION_REPO"
  else
    PUBLIC_REPO_FULLNAME="$(            \
      echo "$GITHUB_REPOSITORY"         \
      | sed -nr 's|^(.+)_private$|\1|p' \
    )"
  fi
  echo "INPUT_DESTINATION_REPO = $INPUT_DESTINATION_REPO"
  echo "PUBLIC_REPO_FULLNAME = $PUBLIC_REPO_FULLNAME"
  if [ ! $PUBLIC_REPO_FULLNAME ]; then
    echo "We were not given a name for the public repo, nor could we automatically determine a suitable one from the private repo name. Please provide a public repo name through the 'destination_repo' argument."
    exit 4
  fi

  echo "INPUT_WORKING_BRANCH_NAME = $INPUT_WORKING_BRANCH_NAME"
  # Rename for clarity of what it's purpose is within the script
  TARGET_BRANCH=$INPUT_WORKING_BRANCH_NAME
  # TODO: Resolve branch names

  PUBLIC_REPO_DIR=$(mktemp -d)
  echo "Cloning public git repository"
  git config --global user.email "$INPUT_USER_EMAIL"
  git config --global user.name "$INPUT_USER_NAME"
  git clone --single-branch --branch "$GITHUB_BASE_REF" "https://x-access-token:$INPUT_REPO_LEVEL_SEC@$INPUT_GIT_SERVER/$PUBLIC_REPO_FULLNAME.git" "$PUBLIC_REPO_DIR"

  git -C "$PUBLIC_REPO_DIR" fetch --all
  if [ "$(git -C "$PUBLIC_REPO_DIR" branch -l "$TARGET_BRANCH")" ]; then
    echo "TODO: Handle branch existing in public already"
  fi
  git -C "$PUBLIC_REPO_DIR" checkout -b "$TARGET_BRANCH"


  PUBLIC_GITIGNORE_FILE="$PUBLIC_REPO_DIR/.gitignore"
  echo "PUBLIC_GITIGNORE_FILE = $PUBLIC_GITIGNORE_FILE"
  # If the GitHub Action was not configured to run in parallel checkout, the
  # public repo will be within the private repo and will cause problems when
  # copying so we need to add it to the (rsync).gitignore.
  echo "$PUBLIC_REPO_DIR" >> "$PUBLIC_GITIGNORE_FILE"
  echo ".gitignore" >> "$PUBLIC_GITIGNORE_FILE"

  echo "INPUT_COMMIT_MESSAGE = $INPUT_COMMIT_MESSAGE"
  INPUT_COMMIT_MESSAGE="Commit passed along by $GITHUB_ACTION_REPOSITORY. Original commit message: $INPUT_COMMIT_MESSAGE"


  # ####################################################### TODO: DEBUG STATEMENTS
  # pwd
  # ls -la .
  # ls -la /
  # ls -la ~/
  # ####################################################### TODO: DEBUG STATEMENTS

  # Start with a blank exclude file
  ls -la "$PUBLIC_REPO_DIR"
  # cat "/dev/null" > "$PUBLIC_GITIGNORE_FILE"
  # for f in $(find "$PRIVATE_REPO_DIR" -name "public.gitignore"); do
  find "$PRIVATE_REPO_DIR" -name "$INPUT_PUBLIC_GITIGNORE_FILENAME_CONVENTION" \
  | while read -r f
  do
    sed -nr "s|^([^#].+)$|${f}/\1|p"                                     \
    < "$f"                                                               \
    | sed -r "s|^\\$PRIVATE_REPO_DIR/(.+/)?$(basename "$f")/(.+)$|\1\2|" \
    >> "$PUBLIC_GITIGNORE_FILE"
  done
  cat "$PUBLIC_GITIGNORE_FILE"
  git -C "$PUBLIC_REPO_DIR" status


  # echo "Adding git commit"
  # git -C "$PUBLIC_REPO_DIR" add .
  # if git -C "$PUBLIC_REPO_DIR" status | grep -q "Changes to be committed"
  # then
  #   git -C "$PUBLIC_REPO_DIR" commit --message "$INPUT_COMMIT_MESSAGE"
  #   echo "Pushing git commit"
  #   git -C "$PUBLIC_REPO_DIR" push -u origin HEAD:"$TARGET_BRANCH"
  # else
  #   echo "No changes detected"
  # fi
  cd "$PUBLIC_REPO_DIR"
  git config --global user.email "$INPUT_USER_EMAIL"
  git config --global user.name "$INPUT_USER_NAME"
  echo "Adding git commit"
  git add .
  if git status | grep -q "Changes to be committed"
  then
    git commit --message "$INPUT_COMMIT_MESSAGE"
    echo "Pushing git commit"
    git push "https://github.com/connorjbracy/archived_projects.git" "$TARGET_BRANCH"
  else
    echo "No changes detected"
  fi
} 2>&1
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
