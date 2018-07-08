#!/usr/bin/bash

# exit on first failure
set -e
# fail on expanding unset variable
set -u
# fail on some error inside the pipe
set -o pipefail
# print shell input line as they are read
#set -v
# expand commands
#set -x

function fail
{
    printf '%s\n' "${1}" >&2
    exit 1
}

function info
{
    printf '%s\n' "${1}"
}

if [[ ${#} -ne 1 ]]
then
    fail 'expected exactly one parameter - a name of a new test'
fi

name="${1}"
asciirange='[0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZZ]+'
if [[ ! "${name}" =~ ^$asciirange(-$asciirange)*$ ]]
then
    fail "name '${name}' should consist only of groups of one or more ASCII alphanumeric characters separated with a single dash"
fi

dir=$(dirname "${0}")
alltestsdir="${dir}/tests"
name="${1}"
testdir="${alltestsdir}/${name}"

if [[ -e "${testdir}" ]]
then
    fail "test '${name}' already exists"
fi

expecteddir="${testdir}/expected"
gitinitdir="${testdir}/git-init"
repodir="${testdir}/repo"
bakdir="${testdir}/bak"

mkdir -p "${expecteddir}"
mkdir -p "${repodir}"
mkdir -p "${gitinitdir}"
mkdir -p "${bakdir}"

git -C "${repodir}" init --quiet
info "

You are in the directory with the git repo. Create an initial commit
that will serve as a 'git-init' for the '$name' test. Then create a
set of commits. From those commits the script will generate a set of
'expected' patches. The script will then squash the commits into a
single one and generate a single patch that will serve as a base for
'test.patch'. Quit the shell with 'exit' command or press ctrl-d when
you are done.

"

(cd "${repodir}"; PS1='[git-init-test-prep]\$ ' bash)

commit_count=$(git -C "${repodir}" rev-list --count HEAD 2>/dev/null || info '0')

if [[ $commit_count -eq 0 ]]
then
    fail 'No commits in the git init repo'
fi
if [[ $commit_count -eq 1 ]]
then
    fail 'Only init commit in the git init repo. We need at least two more commits there.'
fi

if [[ $commit_count -lt 3 ]]
then
    fail 'We need at least two commits for the expected patches'
fi

noninit_commit_count=$(($commit_count - 1))
roofs=$(printf '^%.0s' $(seq 1 ${noninit_commit_count}))
rev="HEAD${roofs}"

git -C "${repodir}" format-patch --quiet "${rev}"
mv "${repodir}/00"*.patch "${expecteddir}"
git -C "${repodir}" reset --quiet --soft "${rev}"
git -C "${repodir}" commit --quiet --message=merged
git -C "${repodir}" format-patch --quiet HEAD^
mv "${repodir}/0001-merged.patch" "${testdir}/test.patch"
git -C "${repodir}" reset --quiet --hard HEAD^
files=()
for f in $(git -C "${repodir}" ls-files)
do
    files+=("${repodir}/${f}")
done
cp -a "${files[@]}" "${gitinitdir}"
rm -rf "${repodir}"
sed \
    -i'' \
    -e 's/^From [a-f0-9]\{40\}/From 1111111111111111111111111111111111111111/' \
    -e 's/^\(similarity index\).*/\1 42%/g' \
    -e 's/^\( rename .* => .*\) ([0-9]*%)/\1 (42%)/g' \
    -e 's/^index 0000000\.\.[0-9a-f]\{7\}/index xxx..2222222/g' \
    -e 's/^index [0-9a-f]\{7\}\.\.0000000/index 1111111..xxx/g' \
    -e 's/^index [0-9a-f]\{7\}\.\.[0-9a-f]\{7\}/index 1111111..2222222/g' \
    -e 's/^index xxx..2222222/index 0000000..2222222/g' \
    -e 's/^index 1111111..xxx/index 1111111..0000000/g' \
    -e 's/^[0-9]\+\.[0-9]\+\.[0-9]\+$/0.0.0/' \
    -e 's/^\(@@ -[0-9]\+\(,[0-9]\+\)\? +[0-9]\+\(,[0-9]\+\)\? @@\).*$/\1/g' \
    "${expecteddir}/"*patch

for f in "${expecteddir}/"*.patch "${testdir}/test.patch"
do
    cp "${f}" "${bakdir}"
done

info "

Done.

Edit '${testdir}/test.patch' so kgps can generate expected
patches. Optionally, edit expected patches in '${expecteddir}' to
adapt them to your needs. Also, all these files have backups in
'${bakdir}'.

"
