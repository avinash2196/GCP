gcloud services enable cloudbuild.googleapis.com secretmanager.googleapis.com sqladmin.googleapis.com compute.googleapis.com

# Odoo 18 GCP Deployment Using Terraform

This Terraform setup will:
- Enable required services (Cloud SQL, Secret Manager)
- Create a Postgres database
- Create a GCP Compute VM for Odoo
- Set up Secret Manager to store DB password securely
- Configure nginx automatically for Odoo reverse proxy

# Import existing resources

#!/bin/bash

echo "Importing Cloud SQL Instance..."
terraform import google_sql_database_instance.odoo_db_instance projects/hippa-docai-demo/instances/odoo18-db-test

echo "Importing Cloud SQL Database..."
terraform import google_sql_database.odoo_db projects/hippa-docai-demo/instances/odoo18-db-test/databases/odoo18-test

echo "Importing Cloud SQL User..."
terraform import google_sql_user.odoo_db_user hippa-docai-demo/odoo18-db-test/odoo18

echo "Importing Secret Manager Secret..."
terraform import google_secret_manager_secret.odoo_db_password projects/hippa-docai-demo/secrets/odoo18-db-password

echo "Importing Firewall Rule..."
terraform import google_compute_firewall.allow_odoo_http projects/hippa-docai-demo/global/firewalls/allow-odoo-http-test

echo "Importing Compute VM..."
terraform import google_compute_instance.odoo_vm projects/hippa-docai-demo/zones/us-central1-a/instances/odoo18-vm-test

echo "✅ All resources imported successfully!"


## How to Use

gcloud iam service-accounts create cloudbuild-executor --display-name="Cloud Build Executor SA"
gcloud projects add-iam-policy-binding hippa-docai-demo \
  --member="serviceAccount:cloudbuild-executor@hippa-docai-demo.iam.gserviceaccount.com" \
  --role="roles/compute.admin" \
  --condition='expression=true,title=cloudbuild-permanent-access'

gcloud projects add-iam-policy-binding hippa-docai-demo \
  --member="serviceAccount:cloudbuild-executor@hippa-docai-demo.iam.gserviceaccount.com" \
  --role="roles/compute.instanceAdmin.v1" \
  --condition='expression=true,title=cloudbuild-permanent-access'

gcloud projects add-iam-policy-binding hippa-docai-demo \
  --member="serviceAccount:cloudbuild-executor@hippa-docai-demo.iam.gserviceaccount.com" \
  --role="roles/cloudsql.admin" \
  --condition='expression=true,title=cloudbuild-permanent-access'

gcloud projects add-iam-policy-binding hippa-docai-demo \
  --member="serviceAccount:cloudbuild-executor@hippa-docai-demo.iam.gserviceaccount.com" \
  --role="roles/secretmanager.admin" \
  --condition='expression=true,title=cloudbuild-permanent-access'

gcloud projects add-iam-policy-binding hippa-docai-demo \
  --member="serviceAccount:cloudbuild-executor@hippa-docai-demo.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --condition='expression=true,title=cloudbuild-permanent-access'

gcloud projects add-iam-policy-binding hippa-docai-demo \
  --member="serviceAccount:cloudbuild-executor@hippa-docai-demo.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter" \
  --condition='expression=true,title=cloudbuild-permanent-access'





Go to GCP Console → IAM & Admin → IAM

Find this Service Account:

css
Copy
Edit
[PROJECT_NUMBER]@cloudbuild.gserviceaccount.com
Click "Edit Permissions".

Add Role:

Compute Instance Admin (v1)

(Optional) Also Service Account User role for maximum flexibility

✅ Save.
1: Go to GCP Console
🔵 Open →
Cloud Build → Triggers → (Your Project)

2: Click "Connect Repository"
Click “Manage Repositories” or “Connect Repository” (depends on GCP UI).

Choose GitHub.

Authorize Google Cloud to GitHub (OAuth window will open).

✅ Grant access to the repository (or your GitHub organization).
Next Steps
1. Create a GCP Project manually (and link Billing).
2. Upload this Terraform zip to Cloud Shell or your bucket.
3. Unzip and configure:
4. Add Trigger manually and add service account cloudbuild-executor
```bash
unzip odoo18-terraform-final-superclean-fixed.zip
cd odoo18-terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
# Fill your project_id, db_password, resource names
terraform init
terraform apply
```

Then access your Odoo at `http://your-vm-public-ip/`.

---

gcloud iam service-accounts keys create signed-url-key.json   --iam-account=signed-url-sa@hippa-docai-demo.iam.gserviceaccount.com

gsutil signurl -d 1h signed-url-key.json gs://terraform_scripts_demo/odoo18-terraform-final.zip