echo '-------Remove Velero for GKE and Clean up (typically in 3 mins)'
starttime=$(date +%s)
source ./setenv.sh

velero uninstall --force
gsutil -m rm -r gs://$(cat bucket4velero1)/**
rm vinay-velero
gcloud iam service-accounts delete $(gcloud iam service-accounts list --filter="displayName:Velero service account" --format='value(email)') -q

endtime=$(date +%s)
duration=$(( $endtime - $starttime ))
echo ""
echo "-------Total time to clean up the environment is $(($duration / 60)) minutes $(($duration % 60)) seconds."
echo ""

