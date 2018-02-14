#!/bin/bash
#The script will install the logging stack on the host.
set -o nounset
set -o pipefail
echo "////////////////////////////////////////////////////////////////////////////////////"
echo "Please make sure the images and versions are defined correctly in the deployer.yaml."
echo "////////////////////////////////////////////////////////////////////////////////////"

#check who is the user logged in or ask for login if not
oc whoami || (echo "you must login" && oc login)

#Deleting the sa, clusterroles, rolebindings and PV if there are any as they sometimes stops the deployment for eg  in cases of re-install
echo "Deleting the existing service accounts and persistent volume if there is/are any"
oc delete sa aggregated-logging-curator aggregated-logging-elasticsearch aggregated-logging-fluentd aggregated-logging-kibana
oadm policy remove-cluster-role-from-user oauth-editor system:serviceaccount:logging:logging-deployer
oadm policy remove-cluster-role-from-user cluster-reader system:serviceaccount:logging:logging-fluentd
oadm policy remove-cluster-role-from-user rolebinding-reader system:serviceaccount:logging:logging-elasticsearch
oc delete oauthclients kibana-proxy
oc delete pv elasticsearch-storage-1
oc delete rolebinding logging-deployer-dsadmin-role logging-deployer-edit-role logging-elasticsearch-view-role



#Create the project
echo "Proceeding with the loggin stack creation"
oadm new-project logging --node-selector=""
oc project logging

#Apply the deployer.yaml
echo "applying the deployer.yaml template"
oc apply -n openshift -f deployer.yaml
oc new-app logging-deployer-account-template

#Add the secret
echo "Adding the secret"
oc create secret generic logging-deployer

#Set the policies for the service accounts
echo "Setting the policies"
oadm policy add-cluster-role-to-user oauth-editor system:serviceaccount:logging:logging-deployer
oadm policy add-scc-to-user privileged system:serviceaccount:logging:aggregated-logging-fluentd
oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:logging:aggregated-logging-fluentd
oadm policy add-cluster-role-to-user rolebinding-reader system:serviceaccount:logging:aggregated-logging-elasticsearch

set -e

#Readng the values for the kibana hostname and public master url from the master-config.yaml file
hostname=`grep 'subdomain' /etc/origin/master/master-config.yaml | awk -F: {'print $2'} | cut -d"\"" -f2- | tr -d '"'`
url=`grep 'masterPublicURL' /etc/origin/master/master-config.yaml |cut -d':' -f2-| head -n1 | tr -d ' '`
echo ${hostname}
echo ${url}

#Create the configmap
echo "Creating the configmap logging-deployer, for any changes execute oc edit configmap logging-deployer"
oc create configmap logging-deployer --from-literal kibana-hostname=kibana-logging.${hostname} --from-literal public-master-url=${url} --from-literal es-cluster-size=1 --from-literal es-instance-ram=8G --from-literal es-pvc-dynamic="true" --from-literal es-pvc-size=50G

set +e

#Install the deployer from template
echo "Installing the Deployer"
oc new-app logging-deployer-template -p MODE=install
echo "Creating pv.yaml file for ElasticSearch"


#Setting the errexit below for any issues related to the pod, pv etc and hence it will quit.
set -e

#Create a pv.yaml file
#Removed the double quotes for $SIZE, $NFS_SRV, $NFS_PATH so that they appear as it is in the file
#Make sure about the spacing in the yaml else it might fail.
cat > ./pv.yaml << 'EOF'
    apiVersion: v1
    kind: Template
    metadata:
      name: pv.yaml
      annotations:
        description: PV for ElasticSearch.
    objects:
    - kind: PersistentVolume
      apiVersion: v1
      metadata:
        name: elasticsearch-storage-1
      spec:
        accessModes:
        - ReadWriteMany
        capacity:
          storage: ${SIZE}
        nfs:
          path: ${NFS_PATH}
          server: ${NFS_SRV}
        persistentVolumeReclaimPolicy: Retain
    parameters:
    - name: NFS_PATH
      value: ${NFS_PATH}
    - name: NFS_SRV
      value: "nfs1"
    - name: SIZE
      value: "50Gi"
EOF

#Read the nfs export path to be presented to the ES.
read -p "enter the exports name for ElasticSearch Storage: " NFS_PATH

#Process and apply the pv.yaml file
oc process -f pv.yaml -p NFS_PATH="$NFS_PATH" | oc apply -f -
oc get pv

set +e

#Giving time for the pvc for ES pod to come up so and then initiate the patching.
pvc=""

while [[ -z $pvc ]] ; do
        pvc=`oc get pvc -n logging | grep logging | cut -d'-' -f1`
        sleep 3
done

set -e
#Patching the PVC for elastic search and rollingout the new ES pod
echo "Patching the PVC template for ElasticSearch"
oc patch pvc/logging-es-1 --patch '{"spec":{"volumeName" : "elasticsearch-storage-1"}}'
oc get pvc

set +e

#Labelling nodes for Fluentd
oc label node --all logging-infra-fluentd=true


set -e
#fix the Curator settings.
cat > ./config-curator.yaml << 'EOF'
apiVersion: v1
data:
  config.yaml: |+
    # Logging example curator config file

    # uncomment and use this to override the defaults from env vars
    .defaults:
      delete:
        days: 7
      runhour: 0
      runminute: 0

    # to keep ops logs for a different duration:
    .operations:
      delete:
        weeks: 1

    # example for a normal project
    #myapp:
    #  delete:
    #    weeks: 1

kind: ConfigMap
metadata:
  labels:
    logging-infra: support
  name: logging-curator
  namespace: logging
EOF
oc replace -f curator-config.yaml
oc rollout latest logging-curator

echo "//////////////////////////////////////////////////////////"
echo "                    Status of the pods                    "
echo "//////////////////////////////////////////////////////////"
oc get pods -n logging

#Remove the pv.yaml file
rm -f pv.yaml
rm -f logging-curator.yaml
