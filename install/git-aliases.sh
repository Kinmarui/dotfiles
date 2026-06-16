#!/usr/bin/env bash
# Global git aliases. Adapted from omakub install/terminal/set-git.sh (identity
# handling dropped — set user.name/user.email in the private overlay).
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global pull.rebase true
ok "git aliases set (co/br/ci/st, pull.rebase)"
