echo '-------Deploy Velero for GKE Backup (typically in 1 min)'
starttime=$(date +%s)
source ./setenv.sh

echo "-------Download and Install Velero CLI if needed"
if [ ! -x "/usr/bin/velero" ]; then
    # Velero is not installed in /usr/bin, so proceed with installation
    echo "Velero is not installed in /usr/bin. Downloading and installing..."
   #wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
   # tar -zxvf velero-v1.12.0-linux-amd64.tar.gz
   #sudo mv velero-v1.12.0-linux-amd64/velero /usr/bin
    #sudo rm velero-v1.12.0-linux-amd64.tar.gz
    #sudo rm -rf velero-v1.12.0-linux-amd64##
    wget https://github.com/vmware-tanzu/velero/releases/download/v1.13.2/velero-v1.13.2-linux-amd64.tar.gz
    tar -zxvf velero-v1.13.2-linux-amd64.tar.gz
    sudo mv velero-v1.13.2-linux-amd64/velero /usr/bin
    sudo rm velero-v1.13.2-linux-amd64.tar.gz
    sudo rm -rf velero-v1.13.2-linux-amd64
else
    echo "Velero is already installed in /usr/bin."
fi


echo "-------Create a GCS storage bucket if not exist"
cat bucket4velero1
if [ `echo $?` -eq 1 ]; then
  echo $MY_BUCKET-$(date +%d%H%M%s) > bucket4velero1
  gsutil mb gs://$(cat bucket4velero1)/
fi

echo "-------Create a service account for Velero"
gcloud iam service-accounts list | grep vinay-test
if [ `echo $?` -eq 1 ]; then
  export MY_PROJECT_ID=$(gcloud config get-value project)
  MY_GSA_NAME=vinay-test

  gcloud iam service-accounts create $MY_GSA_NAME \
    --display-name "Velero service account"

  MY_SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:Velero service account" \
    --format 'value(email)')

  ROLE_PERMISSIONS=(
    compute.disks.get
    compute.projects.get
    compute.disks.create
    compute.disks.createSnapshot
    compute.snapshots.get
    compute.snapshots.create
    compute.snapshots.useReadOnly
    compute.snapshots.delete
    compute.zones.get
    storage.objects.create
    storage.objects.delete
    storage.objects.get
    storage.objects.list
    iam.serviceAccounts.signBlob
  )

  gcloud iam roles list --project $MY_PROJECT_ID | grep Velero
  if [ `echo $?` -eq 1 ]; then
    gcloud iam roles create velero.server \
      --project $MY_PROJECT_ID \
      --title "Velero Server" \
      --permissions "$(IFS=","; echo "${ROLE_PERMISSIONS[*]}")"
  fi

  gcloud projects add-iam-policy-binding $MY_PROJECT_ID \
    --member serviceAccount:$MY_SERVICE_ACCOUNT_EMAIL \
    --role projects/$MY_PROJECT_ID/roles/velero.server

  gsutil iam ch serviceAccount:$MY_SERVICE_ACCOUNT_EMAIL:objectAdmin gs://$(cat bucket4velero1)

  gcloud iam service-accounts keys create vinay-velero \
    --iam-account $MY_SERVICE_ACCOUNT_EMAIL

  echo "-------Install Velero using the service account"
  velero install \
    --provider gcp \
    --plugins velero/velero-plugin-for-gcp:v1.9.0 \
    --bucket $(cat bucket4velero1) \
    --use-node-agent \
    --uploader-type restic \
    --secret-file ./vinay-velero
fi

echo "-------One time On-Demand Backup of kafka namespace"
kubectl wait --for=condition=ready --timeout=180s -n velero pod -l component=velero
velero backup create kafka-backup --include-namespaces kafka

#echo "-------Hourly scheduled backup of Kafka namespace"
#kubectl create -f velero-schedule.yaml

endtime=$(date +%s)
duration=$(( $endtime - $starttime ))
echo ""
echo "-------Total time to enable Velero backup for GKE is $(($duration / 60)) minutes $(($duration % 60)) seconds."
echo ""


