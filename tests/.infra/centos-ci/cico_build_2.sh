#!/usr/bin/env bash
# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
set -e
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
eval "$(./env-toolkit load -f jenkins-env.json -r \
        CHE_BOT_GITHUB_TOKEN \
        CHE_MAVEN_SETTINGS \
        CHE_GITHUB_SSH_KEY \
        ^BUILD_NUMBER$ \
        CHE_OSS_SONATYPE_GPG_KEY \
        CHE_OSS_SONATYPE_PASSPHRASE \
        QUAY_ECLIPSE_CHE_USERNAME \
        QUAY_ECLIPSE_CHE_PASSWORD)"
printenv
echo '====='$BUILD_NUMBER
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'

