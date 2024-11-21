#!/bin/sh

# This parses the .gitmodules file and gets the path of each submodule.
git config -f .gitmodules --get-regexp '^submodule\..*\.path$' |
    while read path_key path
    do

        # Now we can also get the url and branch, but replacing the ".path" with ".url", ".branch"
        url_key=$(echo $path_key | sed 's/\.path/.url/')
        branch_key=$(echo $path_key | sed 's/\.path/.branch/')
        url=$(git config -f .gitmodules --get "$url_key")
        branch=$(git config -f .gitmodules --get "$branch_key")

        # Check if branch is empty, as it often won't be there.
        if [ -z "$branch" ]; then
            git submodule add $url $path
        else
            git submodule add -b $branch $url $path
        fi

    done
