#!/bin/sh
# Vercel runs this in apps/admin_portal. Exit 0 skips the build, 1 builds.
base=${VERCEL_GIT_PREVIOUS_SHA:-}
remote=$(git remote get-url origin 2>/dev/null || echo https://github.com/vastaso88/VET-APP.git)

if [ -n "$base" ]; then
    # Compare the whole push with the last successful deploy on this branch.
    if ! git cat-file -e "$base^{commit}" 2>/dev/null; then
        git fetch --quiet --depth=1 "$remote" "$base" || exit 1
    fi
elif [ "${VERCEL_ENV:-}" = preview ]; then
    # A new preview branch has no previous deploy. Check it against main.
    main=refs/remotes/origin/main
    if ! git rev-parse --verify --quiet "$main" >/dev/null; then
        git fetch --quiet --depth=10 "$remote" refs/heads/main || exit 1
        main=FETCH_HEAD
    fi
    base=$(git merge-base HEAD "$main") || base=$main
else
    # Allow the first production build when there is no deployed revision.
    exit 1
fi

git diff --quiet "$base" HEAD -- . || exit 1
