#!/usr/bin/env bash

# Copyright (c) 2017 Gawain Lynch <gawain.lynch@gmail.com>
#
# For the full copyright and license information, please view the LICENSE file
# that was distributed with this source code.

if [ $(echo $BASH_VERSION | awk -F "." '{print $1}') -lt 4 ] ; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Bash 4.0 or greater required."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
fi

if [[ ! -f ".gitsubtree" ]] ; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "No .gitsubtree configuration file found"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
fi

REMOTE_BASE_URL=
MONOLITH_REPO_ROOT=
SUBTREE_REPO_ROOT=
declare -A PREFIX_DIRS

source .gitsubtree

[[ "${REMOTE_BASE_URL}" == "" ]] && echo "REMOTE_BASE_URL parameter not set" && exit 1
[[ "${MONOLITH_REPO_ROOT}" == "" ]] && echo "MONOLITH_REPO_ROOT parameter not set" && exit 1
[[ "${SUBTREE_REPO_ROOT}" == "" ]] && echo "SUBTREE_REPO_ROOT parameter not set" && exit 1
[[ -z ${#PREFIX_DIRS[@]} ]] && echo "PREFIX_DIRS parameter not set" && exit 1

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Processing ${#PREFIX_DIRS[@]} subtrees for this repository"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

function fail_gracefully () {
    echo
    echo "Exiting due to error!"
    echo
    exit 1
}

function test_source () {
    pushd "${MONOLITH_REPO_ROOT}" &> /dev/null
    git rev-parse &> /dev/null
    FAIL=$?
    popd &> /dev/null

    if [[ ${FAIL} -ne 0 ]] ; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Not a valid git repository"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 1
    fi
}

function test_target () {
    if [[ ! -d "${SUBTREE_REPO_ROOT}" ]] ; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Target base directory does not exist!"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 1
    fi
}

function clear_cache () {
    pushd "${MONOLITH_REPO_ROOT}" &> /dev/null
    pushd $(git rev-parse --git-dir) &> /dev/null

    [[ $? -ne 0 ]] && fail_gracefully
    if [[ -d subtree-cache ]] ; then
        echo "- Purging git subtree cache"
        rm subtree-cache/* -rf
    fi

    popd  &> /dev/null
    popd  &> /dev/null
}

function make_subtree_repo () {
    _SUBTREE_DIR_NAME="$1"

    pushd "${SUBTREE_REPO_ROOT}" &> /dev/null

    if [[ ! -d ${_SUBTREE_DIR_NAME} ]] ; then
        echo "- Creating repository: ${_SUBTREE_DIR_NAME}"
        mkdir ${_SUBTREE_DIR_NAME}
        pushd ${_SUBTREE_DIR_NAME} &> /dev/null
        git init --bare
        [[ $? -ne 0 ]] && fail_gracefully

        echo "- Adding 'origin' remote: ${REMOTE_BASE_URL}/${_SUBTREE_DIR_NAME}"
        git remote add origin "${REMOTE_BASE_URL}/${_SUBTREE_DIR_NAME}"
        [[ $? -ne 0 ]] && fail_gracefully

        echo "- Creating remote database"
        git remote update
        [[ $? -ne 0 ]] && fail_gracefully
        popd &> /dev/null
    else
        echo "- Skipping existing repository: ${_SUBTREE_DIR_NAME}"
    fi

    popd &> /dev/null
}

function remove_temp_branch () {
    _SUBTREE_DIR_NAME="$1"

    pushd "${MONOLITH_REPO_ROOT}" &> /dev/null

    echo "- Removing branch ${_SUBTREE_DIR_NAME}"
    git branch -D ${_SUBTREE_DIR_NAME} &> /dev/null

    popd &> /dev/null
}

function make_temp_branch () {
    _PREFIX_DIR_NAME="$1"
    _SUBTREE_DIR_NAME="$2"
    _BASE_BRANCH="$3"

    pushd "${MONOLITH_REPO_ROOT}" &> /dev/null

    remove_temp_branch "${_SUBTREE_DIR_NAME}"

    echo "- Checking out target branch: ${_BASE_BRANCH}"
    git checkout ${_BASE_BRANCH} -q
    [[ $? -ne 0 ]] && fail_gracefully

    echo "- Creating subtree ${_SUBTREE_DIR_NAME} against ${_BASE_BRANCH}"
    echo "  - git subtree split --prefix=${_PREFIX_DIR_NAME} -b ${_SUBTREE_DIR_NAME} ${_BASE_BRANCH}"
    git subtree split --prefix="${_PREFIX_DIR_NAME}" -b "${_SUBTREE_DIR_NAME}" "${_BASE_BRANCH}"
    [[ $? -ne 0 ]] && fail_gracefully

    popd &> /dev/null
}

function push_subtree_branch_local () {
    _PREFIX_DIR_NAME="$1"
    _SUBTREE_DIR_NAME="$2"
    _BASE_REPO_BRANCH="$3"
    _SUBTREE_REPO_BRANCH="$4"

    pushd "${MONOLITH_REPO_ROOT}" &> /dev/null

    echo "- Pushing ${SUBTREE_REPO_ROOT}/${_SUBTREE_DIR_NAME} to ${_BASE_REPO_BRANCH}:${_SUBTREE_REPO_BRANCH}"
    git subtree push --prefix="${_PREFIX_DIR_NAME}" "${SUBTREE_REPO_ROOT}/${_SUBTREE_DIR_NAME}" "${_SUBTREE_REPO_BRANCH}"
    [[ $? -ne 0 ]] && fail_gracefully

    popd &> /dev/null
}

function push_subtree_remote () {
    _SUBTREE_DIR_NAME="$1"

    pushd "${SUBTREE_REPO_ROOT}/${_SUBTREE_DIR_NAME}" &> /dev/null

    echo "- Pushing to ${REMOTE_BASE_URL}/${_SUBTREE_DIR_NAME}"
    git push origin --mirror --prune
    [[ $? -ne 0 ]] && fail_gracefully

    popd &> /dev/null
}

function process_branch () {
    _PREFIX_DIR_NAME="$1"
    _SUBTREE_DIR_NAME="$2"
    _BRANCH="$3"

    [[ "${_PREFIX_DIR_NAME}" == "" ]] && echo "Parameter 1 missing from process_branch" && exit 1
    [[ "${_SUBTREE_DIR_NAME}" == "" ]] && echo "Parameter 2 missing from process_branch" && exit 1
    [[ "${_BRANCH}" == "" ]] && echo "Parameter 3 missing from process_branch" && exit 1

    pushd "${MONOLITH_REPO_ROOT}" &> /dev/null

    git rev-parse --verify "${_BRANCH}:${_PREFIX_DIR_NAME}" &> /dev/null
    if [[ $? -eq 0 ]] ; then
        make_subtree_repo "${_SUBTREE_DIR_NAME}"
        push_subtree_branch_local "${_PREFIX_DIR_NAME}" "${_SUBTREE_DIR_NAME}" "${_SUBTREE_DIR_NAME}" "${_BRANCH}"
    else
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "SKIPPED: '${_BRANCH}' branch doesn't have directory: ${_PREFIX_DIR_NAME}"
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    fi

    popd &> /dev/null

}

function update_tags () {
    _SUBTREE_DIR_NAME="$1"

    pushd "${MONOLITH_REPO_ROOT}" &> /dev/null

    GIT_COMMON_DIR=$(git rev-parse --git-common-dir)
    GIT_DIR=$(git rev-parse --git-dir)

    git for-each-ref refs/tags |
    while read -r TAG TYPE TAG_REF ; do
        TAG_REF_SHORT=$(echo "${TAG_REF}" | sed 's/refs\/tags\///')

        echo "- Processing tag '${TAG_REF}' (${TAG})"

        # Annotated tags have a separate commit ID to the commit it references
        OLD_TAG_ID=$(git rev-parse "${TAG_REF}^{}")

        if [[ ${TYPE} == "tag" ]] ; then
            GIT_AUTHOR_NAME=$(git for-each-ref "${TAG_REF}" --format='%(*authorname)')
            GIT_AUTHOR_EMAIL=$(git for-each-ref "${TAG_REF}" --format='%(*authoremail)')
            GIT_AUTHOR_DATE=$(git for-each-ref "${TAG_REF}" --format='%(*authordate)')
            GIT_COMMITTER_NAME=$(git for-each-ref "${TAG_REF}" --format='%(*committername)')
            GIT_COMMITTER_EMAIL=$(git for-each-ref "${TAG_REF}" --format='%(*committeremail)')
            GIT_COMMITTER_DATE=$(git for-each-ref "${TAG_REF}" --format='%(*committerdate)')
            GIT_SUBJECT=$(git for-each-ref "${TAG_REF}" --format='%(subject)')
        elif [[ ${TYPE} == "commit" ]] ; then
            GIT_AUTHOR_NAME=$(git for-each-ref "${TAG_REF}" --format='%(authorname)')
            GIT_AUTHOR_EMAIL=$(git for-each-ref "${TAG_REF}" --format='%(authoremail)')
            GIT_AUTHOR_DATE=$(git for-each-ref "${TAG_REF}" --format='%(authordate)')
            GIT_COMMITTER_NAME=$(git for-each-ref "${TAG_REF}" --format='%(committername)')
            GIT_COMMITTER_EMAIL=$(git for-each-ref "${TAG_REF}" --format='%(committeremail)')
            GIT_COMMITTER_DATE=$(git for-each-ref "${TAG_REF}" --format='%(committerdate)')
        else
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            echo "Something is really wrong with the tags here!"
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            exit 1
        fi

        MATCHING_IDS=$(find ${GIT_DIR}/subtree-cache/ -name ${OLD_TAG_ID} | xargs cat | sort | uniq)

        pushd "${SUBTREE_REPO_ROOT}/${_SUBTREE_DIR_NAME}" &> /dev/null
        pushd "$(git rev-parse --git-dir)" &> /dev/null

        for MATCHING_ID in ${MATCHING_IDS} ; do
            git rev-list "${MATCHING_ID}" &> /dev/null
            if [[ $? -eq 0 ]] ; then
                (
                    # If the tag already exists, exit the sub shell
                    git rev-parse "${TAG_REF}^{}" &> /dev/null && exit 0

                    export  GIT_AUTHOR_NAME \
                            GIT_AUTHOR_EMAIL \
                            GIT_AUTHOR_DATE \
                            GIT_COMMITTER_NAME \
                            GIT_COMMITTER_EMAIL \
                            GIT_COMMITTER_DATE
                    (
                        echo "  - Matching ${TAG} to ${MATCHING_ID}"
                        if [[ "${TYPE}" == "tag" ]] ; then
                            git tag -a ${TAG_REF_SHORT} "${MATCHING_ID}" -m "${GIT_SUBJECT}"
                        elif [[ "${TYPE}" == "commit" ]] ; then
                            git tag ${TAG_REF_SHORT} "${MATCHING_ID}"
                        else
                            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                            echo "Something is really wrong with the tags here!"
                            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                            exit 1
                        fi
                        [[ $? -ne 0 ]] && fail_gracefully
                    )
                )
            fi
        done

        popd &> /dev/null
        popd &> /dev/null
    done

    popd &> /dev/null
}

# Ensure we're run from a valid set up
test_source
test_target
clear_cache

for key in ${!PREFIX_DIRS[@]} ; do
    PREFIX_DIR_NAME="${PREFIX_DIRS[${key}]}"
    SUBTREE_DIR_NAME="${key}"

    echo "-------------------------------------------------------------------------------"
    echo "${PREFIX_DIR_NAME}"
    echo "-------------------------------------------------------------------------------"
    echo
    for BRANCH in $(git rev-parse --symbolic --branches | egrep "^[0-9]|master|development") ; do
        process_branch ${PREFIX_DIR_NAME} ${SUBTREE_DIR_NAME} ${BRANCH}
    done

    update_tags ${SUBTREE_DIR_NAME}
    push_subtree_remote ${SUBTREE_DIR_NAME}

    echo
done
