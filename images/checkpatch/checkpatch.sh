#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2020 Authors of Cilium

# Default options for checkpatch
options=(
    --no-tree
    --strict
    --no-summary
    --show-types
    "--color=always"
)

# Report types to ignore
ignore_list=(
    # Errors
    COMPLEX_MACRO
    GIT_COMMIT_ID
    MULTISTATEMENT_MACRO_USE_DO_WHILE
    # Warnings
    COMMIT_LOG_LONG_LINE
    CONSTANT_CONVERSION
    CONST_STRUCT
    EMAIL_SUBJECT
    FILE_PATH_CHANGES
    JIFFIES_COMPARISON
    LEADING_SPACE
    MACRO_WITH_FLOW_CONTROL
    NO_AUTHOR_SIGN_OFF
    PRINTK_WITHOUT_KERN_LEVEL
    TRAILING_SEMICOLON
    TRAILING_STATEMENTS
    VOLATILE
    # Checks
    LONG_LINE_COMMENT
    # Ignore tolerance that comes by default
    C99_COMMENT_TOLERANCE
)
ignores=$(IFS=,; echo "${ignore_list[*]}")

# Report types that checkpatch downgrades from warning to checks for --file
type_list=(
    AVOID_BUG
    DEPRECATED_TERM
    FSF_MAILING_ADDRESS
    LONG_LINE
    #LONG_LINE_COMMENT  # Not desired
    LONG_LINE_STRING
    #PREFER_FALLTHROUGH # fallthrough; not implemented
    #SPDX_LICENSE_TAG   # Downgraded for a specific case, not relevant here
    TYPO_SPELLING
)
types=$(IFS=,; echo "${type_list[*]}")

script_dir="$(dirname "$(realpath "$0")")"

# Script checkpatch.pl comes from the Linux repository. It is available at:
# https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/checkpatch.pl
# The accompanying spelling file can be downloaded from:
# https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/spelling.txt
checkpatch="$script_dir/checkpatch.pl"

HL_START="\e[1;34m"
HL_END="\e[0m"

usage() {
    echo "Usage: $0 [options] [-- checkpatch.pl options]"
    echo "	Run checkpatch on BPF code. By default, run checkpatch on:"
    echo "		- All commits from a PR, if run as a GitHub action"
    echo "		- All commits since parent ref, and diff from HEAD otherwise"
    echo "Options:"
    echo "	-a	(all code) Run checkpatch on all BPF files instead of Git commits"
    echo "	-i	(indulgent) Do not pass '--strict' to checkpatch"
    echo "	-q	(quiet) Pass '--quiet' to checkpatch"
    echo "	-h	Display this help"
    echo "	Options passed after a ' -- ' delimiter are directly passed to"
    echo "	checkpatch.pl (e.g. '$0 -- --fix-inplace')"
    exit "$1"
}

check_cmd() {
    for cmd in "$@"; do
        if ! (command -v "$cmd" >/dev/null); then
            echo "Error: $cmd not found."
            exit 1
        fi
    done
}

update_sources() {
    readarray -d '' sources < <(find bpf -name "*.[ch]" ! -path "bpf/include/elf/*" ! -path "bpf/include/linux/*" -print0)
    if [ "${#sources[@]}" -eq 0 ]; then
        echo "Please run this script from the root of Cilium's repository."
        exit 1
    fi
}

check_commit_subject_width() {
    subject=$(git show -s --pretty=format:%s "$1")
    width=${#subject}
    if [ "$width" -gt 75 ]; then
        echo -e "\e[;31mERROR:\e[;34mCUSTOM:${HL_END} Please avoid long commit subjects (max: 75, found: $width)"
        ret=1
    fi
}

custom_checks() {
    # If the list of custom tests grows, consider moving it to another file.
    check_commit_subject_width "$1"
}

check_commit() {
    echo "========================================================="
    echo "[$i/$nb_commits] Running on $sha"
    echo -e "$HL_START$subject$HL_END"
    echo "========================================================="
    # Recompute list of source files each time in case commit changes it
    update_sources
    (git show --format=email "$sha" -- "${sources[@]}" | "$checkpatch" "${options[@]}" --ignore "$ignores" "${cli_options[@]}") || ret=1
    # Apply custom checks on all commits, whether or not they touch bpf/
    custom_checks "$sha"
}

all_code=0
indulgent=0
OPTIND=1
while getopts "haiq" opt; do
    case "$opt" in
    h)
        usage 0
        ;;
    a)
        all_code=1
        ;;
    i)
        indulgent=1
        for i in "${!options[@]}"; do
            if [[ "${options[i]}" = "--strict" ]]; then
                unset 'options[i]'
                break
            fi
        done
        ;;
    q)
        options+=(--quiet)
        ;;
    *)
        usage 1
        ;;
    esac
done
shift $((OPTIND-1))
[[ "${1:-}" = "--" ]] && shift
cli_options=( "$@" )

# If -a option provided, simply run checkpatch on all *.c *.h code and exit
if [ $all_code -eq 1 ]; then
    update_sources
    echo -e "${HL_START}Checking files:$HL_END $(echo "${sources[@]}" | tr '\n' ' ')"
    ret=0
    "$checkpatch" "${options[@]}" --ignore "$ignores" "${cli_options[@]}" -f "${sources[@]}" || ret=1
    if [ $indulgent -eq 1 ]; then
        echo -e "${HL_START}Second run, to report 'checks' that should normally be 'warnings'...$HL_END"
        # Re-run to cover types downgraded to checks by checkpatch when running
        # on files, to be on par with what we do for commits.
        "$checkpatch" "${options[@]}" --strict --types "$types" "${cli_options[@]}" -f "${sources[@]}" || ret=1
    fi
    echo -e "${HL_START}All done$HL_END"
    exit $ret
fi

check_cmd git jq

if [ -n "$GITHUB_REF" ]; then
    # Running as GitHub action
    # We'll run checkpatch on each commit from the PR
    check_cmd curl
    pr=${GITHUB_REF#"refs/pull/"}
    prnum=${pr%"/merge"}
    pr_url="https://api.github.com/repos/cilium/cilium/pulls/${prnum}"

    # Skip for backports (if not on main branch)
    base_ref=$(curl -s "${pr_url}" | jq -r '.base.ref')
    case "$base_ref" in
    master|main|trunk)
        ;;
    *)
        echo "PR is not based on 'master' branch, likely a backport PR. Skip verification."
        exit 0
        ;;
    esac

    commits_url="${pr_url}/commits"
    list_commits=$(curl -s "$commits_url" | jq '[.[]|{sha: .sha, subject: (.commit.message | sub("\n.*"; ""; "m"))}]')
    pr_info="from PR #$prnum"
else
    # Running locally
    # We'll run checkpatch on each commit since newest parent ref
    parent_ref=$(git log --simplify-by-decoration --pretty=format:'%D' -n 2 | sed -n '2{s/,.*//;s/^tag: //;p}')
    list_commits=$(git log --pretty=format:"%H %s" "$parent_ref".. | awk '
        BEGIN {print "["}
        {
            if (NR>1)
                print ",";
            sha=$1;
            sub(/[^ ]* /, "");
            gsub(/"/, "\\\"");
            print "{\"sha\":\"" sha "\", \"subject\":\"" $0 "\"}"
        }
        END {print "]"}')
    pr_info="on top of ref $parent_ref"
fi
nb_commits=$(echo "$list_commits" | jq length)

echo "Retrieved $nb_commits commits $pr_info"
echo

ret=0
# Run checkpatch for BPF changes on all selected commits
for ((i=0; i<nb_commits; i++)); do
    subject=$(echo "$list_commits" | jq -r ".[$i].subject")
    sha=$(echo "$list_commits" | jq -r ".[$i].sha")
    check_commit "$i" "$nb_commits"
done

# If not a GitHub action and repo is dirty, run on diff from HEAD
if [ -z "$GITHUB_REF" ] && ! (git diff --exit-code && git diff --cached --exit-code) >/dev/null; then
    echo "========================================================="
    echo -e "${HL_START}Running on changes from local HEAD$HL_END"
    echo "========================================================="
    update_sources
    (git diff HEAD -- "${sources[@]}" | "$checkpatch" "${options[@]}" --ignore "$ignores" "${cli_options[@]}") || ret=1
fi

echo -e "${HL_START}All done$HL_END"

exit $ret
