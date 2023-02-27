#!/usr/bin/env bash
# 

GITHUB_ROOT="https://github.com/pinternal"
REPO="pinboard"

# Suggested aliases:
# alias stack-branch=git commit --allow-empty -m
# alias stack-restack=git fetch origin master; git rebase -i origin/master
# alias stack-push-f=yes | create-and-push-pr-stack.sh

_print_help() {
    cat <<HEREDOC

Looks for empty commits since origin/master and uses them to
create/update stacked branches at origin automatically.

You can use this by doing what
<redacted>
says, except create empty commits using 'git commit --allow-empty -m
"[stack-name] [n/N] description"' to mark boundaries between your
desired stacked PRs.  This allows you to automatically rebase and
force-push the PRs in a stack whenever you make changes to the middle
of the stack.

To migrate any large code change into a string of updatable stacked
branches:

1. Checkout your XL branch
2. Make a bunch of empty commits
3. Use git fetch origin master ; git rebase -i origin/master and move the commits around
4. Call create-and-push-pr-stack.sh

When you make changes in the middle of your stack, you can create
commits at the top of your master stack and then send them down via
git rebase -i origin/master.  If it leads to merge conflicts
(especially if new files are being added), you can either resolve them
normally or splinter your commits into smaller fixups before rebasing,
allowing the smaller commits to stop and fixup at different points
when you rebase down the stack (like chromatography).  To split up a
commit into multiple commits, give it "edit" mode during a rebase, and
use git reset HEAD^; git add -p ; git commit [--reuse-message SHA],
repeatedly.

When you land the bottom of your stack into master and fetch+rebase,
you have at least three choices to avoid conflicts between your
unsquashed bottom and its squashed copy on master: (1) drop the shared
commits manually during rebase; (2) squash commits manually during
rebase; or (3) keep only one commit per stacked branch.

Usage:
  create-and-push-pr-stack.sh
  create-and-push-pr-stack.sh -h | --help
Options:
  -h --help  Show this screen.
HEREDOC
}

# Adapted from
# https://stackoverflow.com/questions/3231804/in-bash-how-to-add-are-you-sure-y-n-to-any-command-or-alias
confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? ([y]/n)} " response
    case "$response" in
        [nN][oO]|[nN])
            false
            ;;
        [qQ][uU][iI][tT]|[qQ])
            echo "Sorry, I don't know how to quit. It's safe to use C-c to abort remaining changes."
            false
            ;;
        *)
            true
            ;;
    esac
}

processShaAsBranch () {
    sha="$1"
    branch="$2"

    # Set branch to point to sha
    git branch --quiet -f "$branch" "$sha"
    # Push local branch to remote branch
    push_output="$(git push --no-progress --force-with-lease origin "$branch":"$branch" 2>&1)"
    if [[ "$push_output" =~ "Everything up-to-date" ]]; then
        echo "Already up-to-date. PR: ${GITHUB_ROOT}/${REPO}/pull/${branch}"
    elif [[ "$push_output" =~ "pull request by visiting" ]]; then
        # Nicely, when the branch is new, git gives us this message from remote even with --quiet.
        echo "$push_output"
    else
        echo "$push_output"
        echo "PR: ${GITHUB_ROOT}/${REPO}/pull/${branch}"
    fi
}


createAndPushPRStack () {
    mostRecentBranch="origin/master"
    currPRIsEmpty=1
    # Adapted from https://stackoverflow.com/questions/26683792/how-can-i-find-empty-git-commits
    for sha in $(git rev-list --min-parents=1 --max-parents=1 --reverse origin/master..HEAD)
    do
        # branchTitle = author/commit_title (remove open/close brackets and replace spaces with hyphens)
        branchTitle="$(git show -s --format="%al/%s" "${sha}" | sed 's/[][]//g' | sed 's/[ ]/-/g')"

        git show -s --format="%h %s" "${sha}"
        if [ "$(git rev-parse "${sha}^{tree}")" == "$(git rev-parse "${sha}^1^{tree}")" ]; then
            if [ $currPRIsEmpty -eq 1 ]; then
                confirm "The next branch ${branchTitle} is empty.  Abort? ([y]/n)" && return 0
                echo "Did not abort.  Skipping empty branch ${branchTitle}."
            else
                # Show files changed to help user detect wrongly-merged rebase conflicts
                git diff --name-status -M -C "${mostRecentBranch}" "${sha}" | sed 's/^/      /'
                confirm "Force push to ${branchTitle} with above commits (plus merge commits)? ([y]/n)" && \
                    processShaAsBranch "$sha" "${branchTitle}" && \
                    mostRecentBranch="${sha}"
                currPRIsEmpty=1
            fi
            echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        else
            currPRIsEmpty=0
        fi
    done

    if [ "$mostRecentBranch" == "origin/master" ]; then
        echo "You didn't have any empty commits.  Please do:"
        echo "      git commit --allow-empty -m \"[n/N] [stack-name] description\""
        echo "one or more times to mark the head of each stacked PR, and then use git rebase -i to move them around."
    elif [ $currPRIsEmpty -eq 0 ]; then
        echo "HEAD was not an empty commit.  You may want to add one more empty commit or push from your master stack."
        echo "The last empty commit was ${mostRecentBranch}: $(git show -s --format="%s" "${mostRecentBranch}")"
    else
        echo "Congrats! Your stack has been pushed to origin. 🚀"
    fi
    
}

_main() {
  # Avoid complex option parsing when only one program option is expected.
  if [[ "${1:-}" =~ ^-h|--help$  ]]
  then
    _print_help
  else
    echo "Welcome to git-stack!  Number of non-merge commits since origin/master:"
    git rev-list --min-parents=1 --max-parents=1 --reverse origin/master..HEAD | wc -l
    echo "If this number is larger than you expect, please first run: git fetch origin master ; git rebase -i origin/master"
    confirm "Continue? ([y]/n)" && createAndPushPRStack "$@"
  fi
}

# Call `_main` after everything has been defined.
_main "$@"
