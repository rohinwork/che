#!/usr/bin/env bash
# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html

function archiveArtifacts1(){
  set +e

  JOB_NAME=che-nightly
  echo "Archiving artifacts from ${DATE} for ${JOB_NAME}/${BUILD_NUMBER}"
  ls -la ./artifacts.key
  chmod 600 ./artifacts.key
  chown $(whoami) ./artifacts.key
  mkdir -p ./che/${JOB_NAME}/${BUILD_NUMBER}
  cp  -R ./report ./che/${JOB_NAME}/${BUILD_NUMBER}/ | true
  rsync --password-file=./artifacts.key -Hva --partial --relative ./che/${JOB_NAME}/${BUILD_NUMBER} devtools@artifacts.ci.centos.org::devtools/
  set -e
}

set -e
set +x

echo "****** Starting RH-Che PR check $(date) ******"

total_start_time=$(date +%s)
export PR_CHECK_BUILD="true"
export BASEDIR=$(pwd)
export DEV_CLUSTER_URL=https://devtools-dev.ext.devshift.net:8443/

 eval "$(./env-toolkit load -f jenkins-env.json \
                              CHE_BOT_GITHUB_TOKEN \
                              CHE_MAVEN_SETTINGS \
                              CHE_GITHUB_SSH_KEY \
                              CHE_OSS_SONATYPE_GPG_KEY \
                              CHE_OSS_SONATYPE_PASSPHRASE \
                              QUAY_ECLIPSE_CHE_USERNAME \
                              QUAY_ECLIPSE_CHE_PASSWORD)"

source tests/.infra/centos-ci/functional_tests_utils.sh

pwd
ls -als

echo "Installing dependencies:"
start=$(date +%s)
installDependencies
stop=$(date +%s)
instal_dep_duration=$(($stop - $start))

env

curl -L http://mirrors.ukfast.co.uk/sites/ftp.apache.org/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz | tar -C /opt -xzv
export M2_HOME=/opt/apache-maven-3.3.9
export M2=$M2_HOME/bin
export PATH=$M2:$PATH
export JAVA_HOME=/usr/
mvn --version

sudo curl -L "https://github.com/docker/compose/releases/download/1.25.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "Installing all dependencies lasted $instal_dep_duration seconds."

yum install -y qemu-kvm libvirt libvirt-python libguestfs-tools virt-install

curl -L https://github.com/dhiltgen/docker-machine-kvm/releases/download/v0.10.0/docker-machine-driver-kvm-centos7 -o /usr/local/bin/docker-machine-driver-kvm
chmod +x /usr/local/bin/docker-machine-driver-kvm

systemctl enable libvirtd
systemctl start libvirtd

virsh net-list --all

curl -Lo minishift.tgz https://github.com/minishift/minishift/releases/download/v1.34.2/minishift-1.34.2-linux-amd64.tgz
tar -xvf minishift.tgz --strip-components=1
chmod +x ./minishift
mv ./minishift /usr/local/bin/minishift

minishift version
minishift config set memory 14GB
minishift config set cpus 4
minishift start

oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-admin developer
oc login -u developer -p pass

bash <(curl -sL  https://www.eclipse.org/che/chectl/) --channel=next

echo "====Replace CRD===="
curl -o org_v1_che_crd.yaml https://raw.githubusercontent.com/eclipse/che-operator/63402ddb5b6ed31c18b397cb477906b4b5cf7c22/deploy/crds/org_v1_che_crd.yaml
cp org_v1_che_crd.yaml /usr/local/lib/chectl/templates/che-operator/crds/

if chectl server:start -a operator -p openshift --k8spodreadytimeout=360000 --listr-renderer=verbose
then
        echo "Started succesfully"
else
        echo "==== oc get events ===="
        oc get events
        echo "==== oc get all ===="
        oc get all
        # echo "==== docker ps ===="
        # docker ps
        # echo "==== docker ps -q | xargs -L 1 docker logs ===="
        # docker ps -q | xargs -L 1 docker logs | true
        oc logs $(oc get pods --selector=component=che -o jsonpath="{.items[].metadata.name}") || true
        oc logs $(oc get pods --selector=component=keycloak -o jsonpath="{.items[].metadata.name}") || true
        curl -vL http://keycloak-che.${LOCAL_IP_ADDRESS}.nip.io/auth/realms/che/.well-known/openid-configuration
        exit 1337
fi

CHE_ROUTE=$(oc get route che --template='{{ .spec.host }}')
#curl -vL $CHE_ROUTE

set +x
pwd
echo ${WORKSPACE} || true
export CHE_INFRASTRUCTURE=openshift
export DNS_PROVIDER=nip.io

# configure GitHub test users
#mkdir -p ${WORKSPACE}/codeready_local_conf_dir
#export CHE_LOCAL_CONF_DIR=${WORKSPACE}/codeready_local_conf_dir/
#rm -f ${WORKSPACE}/codeready_local_conf_dir/selenium.properties
#echo "github.username=che6ocpmulti" >> ${WORKSPACE}/codeready_local_conf_dir/selenium.properties
#echo "github.password=CheMain2017" >> ${WORKSPACE}/codeready_local_conf_dir/selenium.properties
#echo "github.auxiliary.username=iedexmain1" >> ${WORKSPACE}/codeready_local_conf_dir/selenium.properties
#echo "github.auxiliary.password=CodenvyMain15" >> ${WORKSPACE}/codeready_local_conf_dir/selenium.properties

#build selenium module
#cd ${WORKSPACE}
#scl enable rh-maven33 'mvn clean install -pl :che-selenium-test -am -DskipTests=true -U'
mvn clean install -pl :che-selenium-test -am -DskipTests=true -U

cd tests/legacy-e2e/che-selenium-test
bash selenium-tests.sh --host=${CHE_ROUTE} --port=80 --multiuser --test=CreateAndDeleteProjectsTest

