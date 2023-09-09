#!/bin/bash
base_api_url="https://api.github.com"
token=$1
repo="cloudymax/pxeless"
runner_plat=linux

export RUNNER_TOKEN=$(curl -s -X POST ${base_api_url}/repos/cloudymax/pxeless/actions/runners/registration-token -H "accept: application/vnd.github.everest-preview+json" -H "authorization: token ${token}" | jq -r '.token')

latest_version_label=$(curl -s -X GET 'https://api.github.com/repos/actions/runner/releases/latest' | jq -r '.tag_name')
latest_version=$(echo ${latest_version_label:1})
runner_file="actions-runner-${runner_plat}-x64-${latest_version}.tar.gz"
runner_url="https://github.com/actions/runner/releases/download/${latest_version_label}/${runner_file}"

wget -O ${runner_file} ${runner_url}
tar xzf "./${runner_file}"

./config.sh --url https://github.com/${repo} \
        --token ${RUNNER_TOKEN} \
        --unattended
