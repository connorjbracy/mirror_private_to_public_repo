## **Note:** This is an adaptation of public GitHub Action [dmnemec/copy_file_to_another_repo_action](https://github.com/dmnemec/copy_file_to_another_repo_action)

# mirror_private_to_public_repo
This GitHub Action is for the purpose of providing a public facing copy of a private repo, with necessarily private files kept from living on the public copy. The workflow looks like:
  - Clone private repo
  - Do work in work branch
  - Commit changes
  - Push changes to (private) origin
  - Open pull request to (private) origin/main
  - *GitHub Actions runs this Action*
    - Find and clone corresponding 'public' counterpart of the private repo
    - Find the base_ref branch (indicated in the private repo's branch history) within the public repo's branches
      - Look for a corresponding head_ref (indicated in the private repo's branch history) within the public repo's branches
        - If `public/<head_ref>` exists, checkout a copy of that branch
        - Else make a new branch named `public/<head_ref>`
    - Look for (arg specified) files following naming convention which are pseudo `.gitignore` files that exist within the private repo.
      - These are "pseudo `.gitignores`" meaning they follow the `.gitignore` format, but are named different than `.gitignore` so that the private git actions do not skip versioning files from these pseudo `.gitignores` (e.g., `public.gitignore`)
      - These pseudo `.gitignore` files will be searched for and their contents will be aggregated into a single `.gitignore` within the public copy of the repo.
      - Each source pseudo `.gitignore` file will have its contents prepended with the relative path from the private project root, if it does not exist within the root directory. 
      - For example, a pseudo `.gitignore` stored in `private/some/subdir/public.gitignore` with entry `hidden.txt` will create a corresponding entry in `public/.gitignore` which reads `some/subdir/hidden.txt`.
    - Copy all files that are not excluded in the `public/.gitignore` from `private/` to `public/` (this is technically redundant as the subsequent commit should skip these files, but it never hurts to be doubly safe).
    - Run `git add .` and `git commit -m "<custom or automatically determined commit message"` on the public repo's working branch
    - Push the changes to the remote `public`.
  

# Example Config
    name: Protect_Private_Files

    on:
      pull_request:

    jobs:
      build:
        runs-on: ubuntu-latest

        steps:
          - uses: actions/checkout@v3
            with:
              path: private

          - name: Mirror private to public
            uses: connorjbracy/mirror_private_to_public_repo@main
            with:
              # github_secret_pat: Required
              github_secret_pat: <specify_GH_PAT_secret_for_pushing_to_the_public_repo>
              # private_subdir: Default => "." (i.e., the GITHUB_WORKSPACE directory)
              private_subdir: 'private'
              ## public_repo: Default => The name of the private repo, with a presumed "_private" truncated from the end.
              # public_repo:
              # user_name: Default => '${{ github.actor }}'
              user_name: 'connorjbracy'
              # user_email: Default => '${{ github.actor }}@users.noreply.github.com'
              user_email: '${{ github.actor }}@users.noreply.github.com'
              ## working_branch_name: Default => '${{ github.head_ref }}'
              # working_branch_name: '${{ github.head_ref }}'
              # commit_message: Default => '${{ github.event.head_commit.message }}'
              commit_message: '${{ github.event.head_commit.message }}'
              # pseudo_gitignore_filename: Default => 'public.gitignore'
              pseudo_gitignore_filename: 'public.gitignore'
              ## git_server: Default => 'github.com'
              # git_server:
              
# Arguments

* github_secret_pat: The secret (typically, [a GitHub PAT](https://github.com/settings/tokens)) used to authorize working with the public repo.
* private_subdir: [optional] The subdir within the GitHub Actions runner that the private repo was checked out into.
  * Default: "." (i.e., the GITHUB_WORKSPACE directory)'
* public_repo: [optional] The name of the public repo (if it differs from the private in a way that can't be automatically determined).
  * Default: The name of the private repo, with a presumed "_private" truncated from the end.
* user_name: [optional] The git username to be responsible for the commit.
  * Default: '${{ github.actor }}'
* user_email: [optional] The git user email to be responsible for the commit.
  * Default: '${{ github.actor }}@users.noreply.github.com'
* working_branch_name: [optional] Specify the name of the branch to use in the public counterpart.
  * Default: '${{ github.head_ref }}'
* commit_message: [optional] Commit message to be passed to the public repo.
  * Default: '${{ github.event.head_commit.message }}'
* pseudo_gitignore_filename: [optional] Naming convention of private's pseudo .gitignore files.
  * Default: '${{ github.event.head_commit.message }}'
* git_server: [optional] Git server host.
  * Default: 'github.com'
