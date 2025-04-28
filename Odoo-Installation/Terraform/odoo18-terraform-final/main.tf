
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.11.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.11.0"
    }
  }
}

provider "google" {
    project = var.project_id
	  region  = var.region
	  zone    = var.zone
}

provider "google-beta" {
   project = var.project_id
	  region  = var.region
	  zone    = var.zone
}




	resource "google_project_service" "sqladmin" {
	  project = var.project_id
	  service = "sqladmin.googleapis.com"
	}

	resource "google_project_service" "secretmanager" {
	  project = var.project_id
	  service = "secretmanager.googleapis.com"
	}

	resource "google_compute_firewall" "allow_odoo_http" {
	  name          = var.firewall_rule_name
	  network       = "default"
	  allow {
		protocol = "tcp"
		ports    = ["80"]
	  }
	  direction     = "INGRESS"
	  priority      = 1000
	  target_tags   = ["odoo-server"]
	  description   = "Allow HTTP traffic to Odoo VM"
	  source_ranges = ["0.0.0.0/0"]
	}

	resource "google_sql_database_instance" "odoo_db_instance" {
	  name             = var.db_instance_name
	  database_version = "POSTGRES_15"
	  region           = var.region

	  settings {
		tier = "db-custom-2-4096"
		availability_type = "ZONAL"
		disk_size = 50
		ip_configuration {
		  authorized_networks {
			value = "0.0.0.0/0"
		  }
		  ipv4_enabled = true
		}
	  }

	  lifecycle {
		prevent_destroy = true
	  }
	}

	resource "google_sql_database" "odoo_db" {
	  name     = var.db_name
	  instance = google_sql_database_instance.odoo_db_instance.name

	  lifecycle {
		prevent_destroy = true
	  }
	}

	resource "google_sql_user" "odoo_db_user" {
	  name     = var.db_user_name
	  instance = google_sql_database_instance.odoo_db_instance.name
	  password = var.db_password
	}

	resource "google_secret_manager_secret" "odoo_db_password" {
	  secret_id = var.secret_name

	  replication {
		user_managed {
		  replicas {
			location = var.replica_location
		  }
		}
	  }

	  lifecycle {
		prevent_destroy = true
		ignore_changes = [
		  replication,
		]
	  }
	}

	resource "google_secret_manager_secret_version" "odoo_db_password_version" {
	  secret      = google_secret_manager_secret.odoo_db_password.id
	  secret_data = var.db_password
	}

	resource "google_compute_instance" "odoo_vm" {
	  name         = var.vm_name
	  machine_type = "e2-medium"
	  zone         = var.zone

	  boot_disk {
		initialize_params {
		  image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
		  size  = 50
		  type  = "pd-balanced"
		}
	  }

	  network_interface {
		network = "default"
		access_config {}
	  }

	  tags = ["http-server", "https-server", "odoo-server"]

	  service_account {
		email  = data.google_compute_default_service_account.default.email
		scopes = ["https://www.googleapis.com/auth/cloud-platform"]
	  }

	  metadata_startup_script = <<-EOT
	#!/bin/bash
	apt update
	apt install -y git curl wget build-essential python3-pip python3-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libjpeg-dev libpq-dev libffi-dev libssl-dev zlib1g-dev libjpeg8-dev python3-venv python3-wheel nginx

	# Setup user and clone Odoo
	useradd -r -m -d /opt/odoo18 odoo18
	cd /opt/odoo18
	sudo -u odoo18 git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 odoo-server
	cd /opt/odoo18/odoo-server
	python3 -m venv venv
	source venv/bin/activate
	pip install wheel
	sed -i "/gevent==/d" requirements.txt
	pip install "gevent==21.12.0" --only-binary :all:
	pip install -r requirements.txt
	deactivate
	mkdir -p /var/log/odoo18
	chown odoo18:root /var/log/odoo18
	mkdir -p /opt/odoo18/odoo-server/custom_addons
	chown odoo18:root /opt/odoo18/odoo-server/custom_addons

	# Setup nginx
	cat <<EOF > /etc/nginx/sites-available/odoo
	server {
		listen 80;
		server_name _;
		access_log  /var/log/nginx/odoo_access.log;
		error_log   /var/log/nginx/odoo_error.log;
		proxy_read_timeout 720s;
		proxy_connect_timeout 720s;
		proxy_send_timeout 720s;
		send_timeout 720s;
		client_max_body_size 200m;
		location / {
			proxy_pass http://127.0.0.1:8069;
			proxy_set_header Host \$host;
			proxy_set_header X-Real-IP \$remote_addr;
			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
			proxy_set_header X-Forwarded-Proto \$scheme;
		}
	}
	EOF

	ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
	rm -f /etc/nginx/sites-enabled/default
	nginx -t && systemctl reload nginx

  # Fetch password from Secret Manager
    export GOOGLE_CLOUD_PROJECT="${var.project_id}"
    DB_PASSWORD=$(gcloud secrets versions access latest --secret=${var.secret_name})
	
	# Setup Odoo Config dynamically
	cat <<EOF > /etc/odoo18.conf
	[options]
	admin_passwd = admin
	db_host = ${google_sql_database_instance.odoo_db_instance.ip_address[0].ip_address}
	db_port = 5432
	db_user = odoo18
	db_password = \$DB_PASSWORD
	addons_path = /opt/odoo18/odoo-server/addons,/opt/odoo18/odoo-server/custom_addons
	logfile = /var/log/odoo18/odoo.log
	xmlrpc_interface = 0.0.0.0
	netrpc_interface = 0.0.0.0
	proxy_mode = True
	http_interface = 0.0.0.0
	EOF

	# Setup Odoo systemd service
	cat <<EOF > /etc/systemd/system/odoo18.service
	[Unit]
	Description=Odoo18
	Requires=network.target
	After=network.target

	[Service]
	Type=simple
	SyslogIdentifier=odoo18
	PermissionsStartOnly=true
	User=root
	Group=root
	ExecStart=/opt/odoo18/odoo-server/venv/bin/python3 /opt/odoo18/odoo-server/odoo-bin -c /etc/odoo18.conf
	StandardOutput=journal+console

	[Install]
	WantedBy=multi-user.target
	EOF

	systemctl daemon-reload
	systemctl enable odoo18
	systemctl start odoo18
	  EOT
	}

	data "google_compute_default_service_account" "default" {}
