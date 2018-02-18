#!/usr/bin/bash

set -e

dir=$(dirname $0)
splitter="${dir}/split.pl"
alltestsdir="${dir}/tests"
resultsdirbase='test-results'
allresultsdir="${resultsdirbase}-$(date '+%Y-%m-%d-%H-%M-%S')"
exitstatus=0

shopt -s nullglob

for testdir in "${alltestsdir}"/*
do
    if [[ ! -d "${testdir}" ]]
    then
        continue
    fi
    expectedfilesdir="${testdir}/expected"
    name=$(basename "${testdir}")
    resultdir="${allresultsdir}/${name}"
    debugdir="${resultdir}/debug"
    diffdir="${debugdir}/diffs"
    patchesdir="${resultdir}/patches"
    mkdir -p "${patchesdir}"
    mkdir -p "${debugdir}"
    mkdir -p "${diffdir}"
    statusfile="${debugdir}/status"
    if [[ "${name}" == 'SKIP'* ]]
    then
        echo "${name} SKIP"
        echo 'SKIP' >"${statusfile}"
        continue
    fi
    failreasons=()
    if ! "${splitter}" \
         --input-patch "${testdir}/test.patch" \
         --output-directory "${patchesdir}" \
         >"${debugdir}/splitter-output" 2>&1
    then
        failreasons+=("splitter failed to process the patch")
    else
        for expectedpatch in "${expectedfilesdir}"/*
        do
            patchname=$(basename "${expectedpatch}")
            actualpatch="${patchesdir}/${patchname}"
            if [[ -e "${actualpatch}" ]]
            then
                patchdiff="${diffdir}/${patchname}.diff"
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
    fi
    if [[ ${#failreasons[@]} -gt 0 ]]
    then
        exitstatus=1
        echo 'FAILURE' >"${statusfile}"
        echo "${name} FAILURE"
        for reason in "${failreasons[@]}"
        do
            echo "  - ${reason}" | tee --append "${debugdir}/reasons"
        done
    else
        echo 'SUCCESS' >"${statusfile}"
        echo "${name} SUCCESS"
    fi
done
rm -f "${resultsdirbase}-latest"
ln -s "${allresultsdir}" "${resultsdirbase}-latest"
exit ${exitstatus}
