# git subtree sync

A small tool for managing read-only subtrees split from a monolithic
development repository.


## Use case

This tool is very limited and if you don't know what git subtrees are, and what
they're useful for then **this is not the tool for you**. :koala:

If you wish to do development of a large project in a single monolithic git
repository, and distribute the components via separate repositories, then
this tool might be useful to you. 

This tool just:
 - Create/updates subtree branches
 - Copies tags from the primary repository to the subtree repositories


## Requirements

- git 1.8.0+
- bash 4.0 or greater
- GNU grep
- GNU awk


## Installation

```bash
git clone https://github.com/GawainLynch/git-subtree-sync.git
sudo ln -s /path/to/git-subtree-sync/git-subtree-sync.sh /usr/local/bin/git-subtree-sync
```

## Configuration

You will need to create a file called `.gitsubtree` in your monolithic repository,
and populate it with the following parameters:

```bash
# Base URL of the upstream subtree repositoies 
REMOTE_BASE_URL=git@github.com:your-org-name

# Full path to the local primary monolithic repo
MONOLITH_REPO_ROOT=/path/to/monolithic/repo

# Full *base* path that will contain the subtree repositories
SUBTREE_REPO_ROOT=/path/to/subtrees

# Bash 4+ associative array of:
#
# Key: Subtree's project name. Will be used for the name of the subtree's 
#      directory under SUBTREE_REPO_ROOT and appended to REMOTE_BASE_URL
#
# Value: The relative path of the subtree in the monolithic repository
#
PREFIX_DIRS=(
    ["project-a"]="src/ProjectA/"
    ["project-b"]="src/ProjectB/"
    ["project-c"]="src/ProjectC/"
)
```

A `.gitsubtree.dist` file is in the root of this repo that can be copies and
adapted as needed.
