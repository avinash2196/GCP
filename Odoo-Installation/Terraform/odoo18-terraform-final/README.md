
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

1. Create a GCP Project manually (and link Billing).
2. Upload this Terraform zip to Cloud Shell or your bucket.
3. Unzip and configure:

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

