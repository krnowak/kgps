#!/usr/bin/bash

# exit on first failure
set -e
# fail on expanding unset variable
set -u
# print shell input line as they are read
#set -v
# expand commands
#set -x

dir=$(dirname $0)
splitter="${dir}/split.pl"
alltestsdir="${dir}/tests"
resultsdirbase='test-results'
allresultsdir="${resultsdirbase}-$(date '+%Y-%m-%d-%H-%M-%S')"
exitstatus=0

function join_path
{
    local IFS='/'
    echo "$*"
}

function rel2rel
{
    local rel_from="${1}"
    local min_count
    local path
    local iter
    local rel_to
    declare -a rel_from_array
    declare -a rel_to_array

    shift

    for rel_to in "$@"
    do
        min_count=0
        path=()
        iter=0
        IFS='/' read -r -a rel_from_array <<< "${rel_from}"
        IFS='/' read -r -a rel_to_array <<< "${rel_to}"

        if [[ ${#rel_from_array[@]} -gt ${#rel_to_array[@]} ]]
        then
            min_count=${#rel_to_array[@]}
        else
            min_count=${#rel_from_array[@]}
        fi
        for iter in $(seq 0 $(($min_count - 1)))
        do
            local f=${rel_from_array[0]}
            local t=${rel_to_array[0]}

            if [[ ${f} != ${t} ]]
            then
                break
            fi
            # shift array
            rel_from_array=("${rel_from_array[@]:1}")
            rel_to_array=("${rel_to_array[@]:1}")
        done
        for iter in "${rel_from_array[@]}"
        do
            path+=('..')
        done
        for iter in "${rel_to_array[@]}"
        do
            path+=("${iter}")
        done
        if [[ ${#path[@]} -gt 0 ]]
        then
            join_path "${path[@]}"
        else
            echo '.'
        fi
    done
}

function git_strip_patch
{
    local path="${1}"
    local target_path="${2}"
    local stage='header'
    local line=''

    truncate --size=0 "${target_path}"
    while IFS='' read -r line || [[ -n "$line" ]]
    do
        line=${line%\\n}
        if [[ $stage = 'header' ]]
        then
            if [[ ${line} = 'From '* ]]
            then
                sed -e 's/[a-f0-9]\{40\}/1111111111111111111111111111111111111111/' <<<"${line}" >>"${target_path}"
            else
                echo "${line}" >>"${target_path}"
                if [[ ${line} == '---' ]]
                then
                    stage='listing'
                fi
            fi
        elif [[ $stage = 'listing' ]]
        then
            echo "${line}" >>"${target_path}"
            if [[ -z $line ]]
            then
                stage='diffs'
            fi
        elif [[ $stage = 'diffs' ]]
        then
            if [[ $line = 'index '* ]]
            then
                sed \
                    -e 's/ 0\+\./ xxx./' \
                    -e 's/\.0000000\( \|$\)/.xxx/' \
                    -e 's/[0-9a-f]\+\./222222./' \
                    -e 's/\.[0-9a-f]\+/.333333/' \
                    -e 's/xxx/000000/g' \
                    <<<"${line}" >>"${target_path}"
            elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
            then
                echo '0.0.0' >>"${target_path}"
            else
                echo "${line}" >>"${target_path}"
            fi
        fi
    done < "${path}"
}

function git_patch_diff
{
    local patch_name="${1}"
    local real_dir="${2}"
    local generated_dir="${3}"
    local help_dir="${4}"
    local patch_dir="${help_dir}/${patch_name}"
    local stripped_real="${help_dir}/${patch_name}/real"
    local stripped_generated="${help_dir}/${patch_name}/generated"

    mkdir -p "${patch_dir}"
    git_strip_patch \
        "${real_dir}/${patch_name}" \
        "${stripped_real}"
    git_strip_patch \
        "${generated_dir}/${patch_name}" \
        "${stripped_generated}"

    diff "${stripped_real}" "${stripped_generated}"
}

# Expects cmdoutputfile and failreasons variables to be set
# up. Returns 1 if command failed.
function call_and_log
{
    local quoted=()
    local param=''
    local cmd_basename=$(basename "${1}")

    for param in "$@"
    do
        quoted+=("'${param}'")
    done
    echo "###" >>"${cmdoutputfile}"
    echo "${quoted[@]}" >>"${cmdoutputfile}"
    echo "###" >>"${cmdoutputfile}"
    if ! "$@" >>"${cmdoutputfile}" 2>&1
    then
        failreasons+=("${cmd_basename} failed, see ${cmdoutputfile}")
        return 1
    fi
    return 0
}

# Expects failreasons, statusfile, name, debugdir variables to be set
# up, variables for colored output are optional. Sets the exitstatus
# variable to 1 if there were any reasons for failure.
function print_status
{
    if [[ ${#failreasons[@]} -gt 0 ]]
    then
        exitstatus=1
        echo 'FAILURE' >"${statusfile}"
        echo -e "${name} ${red}${bold}FAILURE${unbold}${uncolor}"
        for reason in "${failreasons[@]}"
        do
            echo "  - ${reason}" | tee --append "${debugdir}/reasons"
        done
    else
        echo 'SUCCESS' >"${statusfile}"
        echo -e "${name} ${green}${bold}SUCCESS${unbold}${uncolor}"
    fi
    return 0
}

function strip_annotations
{
    local path="${1}"
    local target_path="${2}"
    local stage='non-overlap'
    local line=''

    truncate --size=0 "${target_path}"
    while IFS='' read -r line || [[ -n "$line" ]]
    do
        line=${line%\\n}
        if [[ $stage = 'non-overlap' ]]
        then
            if [[ ${line} =~ ^#[[:space:]]*OVERLAP ]]
            then
                stage='overlap-expect-outcome'
            elif ! [[ ${line} =~ ^# ]]
            then
                echo "${line}" >>"${target_path}"
            fi
        elif [[ $stage = 'overlap-expect-outcome' ]]
        then
            if [[ ${line} =~ ^#[[:space:]]*OUTCOME ]]
            then
               stage='overlap-outcome'
            fi
        elif [[ $stage = 'overlap-outcome' ]]
        then
            if [[ ${line} =~ ^#[[:space:]]*SECTION: ]]
            then
                stage='overlap-sections'
            elif ! [[ ${line} =~ ^# ]]
            then
                echo "${line}" >>"${target_path}"
            fi
        elif [[ $stage = 'overlap-sections' ]]
        then
            if [[ ${line} =~ ^#[[:space:]]*END_OVERLAP ]]
            then
                stage='non-overlap'
            fi
        fi
    done < "${path}"
}

shopt -s nullglob globstar failglob

red=''
green=''
uncolor=''
bold=''
unbold=''
if [[ -t 1 ]]
then
    red='\e[31m'
    green='\e[32m'
    uncolor='\e[39m'
    bold='\e[1m'
    unbold='\e[21m'
fi

mkdir -p "${allresultsdir}"
rm -f "${resultsdirbase}-latest"
ln -s "${allresultsdir}" "${resultsdirbase}-latest"

for testdir in "${alltestsdir}"/*
do
    if [[ ! -d "${testdir}" ]]
    then
        continue
    fi
    testpatch="${testdir}/test.patch"
    expectedfilesdir="${testdir}/expected"
    name=$(basename "${testdir}")
    resultdir="${allresultsdir}/${name}"
    debugdir="${resultdir}/debug"
    diffdir="${debugdir}/diffs"
    patchdiffdir="${diffdir}/patches"
    gitrepodiffdir="${diffdir}/git-repo"
    gitcomparediffdir="${diffdir}/git-compare"
    patchesdir="${resultdir}/patches"
    gitinitdir="${testdir}/git-init"
    gittestdir="${resultdir}/git-test"
    gitsplittestdir="${resultdir}/git-split-test"
    gitrealpatchesdir="${resultdir}/git-real-patches"
    mkdir -p "${patchesdir}"
    mkdir -p "${debugdir}"
    mkdir -p "${patchdiffdir}"
    mkdir -p "${gitrepodiffdir}"
    mkdir -p "${gitcomparediffdir}"
    mkdir -p "${gitrealpatchesdir}"
    # not creating ${gittestdir}, it will be a copy of ${gitinitdir}
    statusfile="${debugdir}/status"
    gittestpatch="${debugdir}/test.patch"
    cmdoutputfile="${debugdir}/cmd-output"
    if [[ "${name}" == 'SKIP'* ]]
    then
        echo 'SKIP' >"${statusfile}"
        echo -e "${name} ${bold}SKIP${unbold}"
        continue
    fi
    failreasons=()
    if ! call_and_log \
         "${splitter}" \
         --output-directory "${patchesdir}" \
         "${testpatch}"
    then
        print_status
        continue
    fi

    for expectedpatch in "${expectedfilesdir}"/*
    do
        patchname=$(basename "${expectedpatch}")
        actualpatch="${patchesdir}/${patchname}"
        if [[ -e "${actualpatch}" ]]
        then
            patchdiff="${patchdiffdir}/${patchname}.diff"
            if diff "${expectedpatch}" "${actualpatch}" >"${patchdiff}"
            then
                rm -f "${patchdiff}"
            else
                failreasons+=("generated patch '${patchname}' differs from the expected one")
            fi
        else
            failreasons+=("missing expected patch '${patchname}'")
        fi
    done
    for actualpatch in "${patchesdir}"/*
    do
        patchname=$(basename "${actualpatch}")
        expectedpatch="${expectedfilesdir}/${patchname}"
        if [[ ! -e "${expectedpatch}" ]]
        then
            failreasons+=("unexpected generated patch '${patchname}'")
        fi
    done
    if [[ -d "${gitinitdir}" ]]
    then
        if ! call_and_log \
             cp -a "${gitinitdir}" "${gittestdir}"
        then
            print_status
            continue
        fi
        if ! call_and_log \
             git -C "${gittestdir}" init
        then
            print_status
            continue
        fi
        if ! call_and_log \
             git -C "${gittestdir}" add .
        then
            print_status
            continue
        fi
        if ! call_and_log \
             git -C "${gittestdir}" commit --message='foo'
        then
            print_status
            continue
        fi
        if ! call_and_log \
             cp -a "${gittestdir}" "${gitsplittestdir}"
        then
            print_status
            continue
        fi
        strip_annotations "${testpatch}" "${gittestpatch}"
        if ! call_and_log \
             git -C "${gittestdir}" am "$(rel2rel "${gittestdir}" "${gittestpatch}")"
        then
            print_status
            continue
        fi
        if ! call_and_log \
             git -C "${gitsplittestdir}" am $(rel2rel "${gitsplittestdir}" "${patchesdir}"/*.patch)
        then
            print_status
            continue
        fi

        for gittestfile in "${gittestdir}"/**
        do
            gittestfilename=${gittestfile#${gittestdir}/}
            if [[ -z "${gittestfilename}" ]]
            then
                continue
            fi
            gitsplittestfile="${gitsplittestdir}/${gittestfilename}"
            if [[ -d "${gittestfile}" ]]
            then
                if [[ ! -d "${gitsplittestfile}" ]]
                then
                    failreasons+=("expected '${gitsplittestfile}' to be a directory")
                fi
            elif [[ -f "${gittestfile}" ]]
            then
                if [[ ! -f "${gitsplittestfile}" ]]
                then
                    failreasons+=("expected '${gitsplittestfile}' to be a regular file")
                else
                    gitrepofilediff="${gitrepodiffdir}/${gittestfilename}.diff"
                    gitrepofilediffdir=$(dirname "${gitrepofilediff}")
                    mkdir -p "${gitrepofilediffdir}"
                    if diff "${gittestfile}" "${gitsplittestfile}" >"${gitrepofilediff}"
                    then
                        rm -f "${gitrepofilediff}"
                    else
                        failreasons+=("file '${gittestfilename}' in '${gitsplittestdir}' differs from the one in '${gittestdir}'")
                    fi
                fi
            else
                failreasons+=("unhandled file '${gittestfile}'")
            fi
        done
        generated_patches=("${patchesdir}"/*.patch)
        if ! call_and_log \
             git -C "${gitsplittestdir}" format-patch \
             --output-directory="$(rel2rel "${gitsplittestdir}" "${gitrealpatchesdir}")" \
             HEAD~${#generated_patches[@]}
        then
            print_status
            continue
        fi
        for idx in $(seq 1 ${#generated_patches[@]})
        do
            num=$(printf '%04d' ${idx})
            generated_patch_name=$(basename "${patchesdir}/${num}"*.patch)
            real_patch_name=$(basename "${gitrealpatchesdir}/${num}"*.patch)
            if [[ "${generated_patch_name}" = "${real_patch_name}" ]]
            then
                gitcomparefilediff="${gitcomparediffdir}/${real_patch_name}.diff"
                if git_patch_diff \
                       "${real_patch_name}" \
                       "${gitrealpatchesdir}" \
                       "${patchesdir}" \
                       "${debugdir}/git-patch-diff-help" \
                       >"${gitcomparefilediff}"
                then
                    rm -f "${gitcomparefilediff}"
                else
                    failreasons+=("generated patch '${real_patch_name}' in '${patchesdir}' differs from the real one in '${gitrealpatchesdir}'")
                fi
            else
                failreasons+=("the generated patch should be named '${real_patch_name}', but it is named '${generated_patch_name}'")
            fi
        done
    fi
    print_status
done
exit ${exitstatus}
