# Configure the Google Cloud provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Configure the provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sql-component.googleapis.com", 
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "containerregistry.googleapis.com",
    "artifactregistry.googleapis.com"  # Added this API
  ])
  
  project = var.project_id
  service = each.value
  
  disable_dependent_services = false
}

# Service Account for Cloud Run and CI/CD
resource "google_service_account" "cloud_run_sa" {
  account_id   = "url-shortener-sa"
  display_name = "URL Shortener Service Account"
  
  depends_on = [google_project_service.apis]
}

# Enhanced IAM roles for the service account
resource "google_project_iam_member" "cloud_run_sa_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor", 
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/run.developer",
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/storage.admin",                    # For GCR access
    "roles/artifactregistry.writer",          # For Artifact Registry
    "roles/containerregistry.ServiceAgent",  # For Container Registry
    "roles/serviceusage.serviceUsageAdmin"   # To enable APIs
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud SQL Database Instance
resource "google_sql_database_instance" "postgres" {
  name             = "url-shortener-db"
  database_version = "POSTGRES_15"
  region           = var.region
  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    disk_size         = 10
    disk_type         = "PD_SSD"
    availability_type = "ZONAL"

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "all"
        value = "0.0.0.0/0"
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Database
resource "google_sql_database" "database" {
  name     = "urlshortener"
  instance = google_sql_database_instance.postgres.name
}

# Database User
resource "google_sql_user" "user" {
  name     = "urlshortener"
  instance = google_sql_database_instance.postgres.name
  password = var.database_password
}

# Secret Manager for database URL
resource "google_secret_manager_secret" "database_url" {
  secret_id = "database-url"
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://${google_sql_user.user.name}:${var.database_password}@${google_sql_database_instance.postgres.public_ip_address}:5432/${google_sql_database.database.name}"
}

# Secret Manager IAM
resource "google_secret_manager_secret_iam_member" "database_url_access" {
  secret_id = google_secret_manager_secret.database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Run Service
resource "google_cloud_run_service" "url_shortener" {
  name     = "url-shortener"
  location = var.region
  
  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10"
        "autoscaling.knative.dev/minScale" = "0"
        "run.googleapis.com/cpu-throttling" = "false"
      }
    }
    
    spec {
      service_account_name = google_service_account.cloud_run_sa.email
      container_concurrency = 100
      timeout_seconds = 300
      
      containers {
        image = "gcr.io/cloudrun/hello"
        
        ports {
          container_port = 8000
        }
        
        env {
          name  = "DATABASE_URL"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.database_url.secret_id
              key  = "latest"
            }
          }
        }
        
        env {
          name  = "BASE_URL"
          value = "https://url-shortener-url-shortener-20250527232607.a.run.app"
        }
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
        
        startup_probe {
          http_get {
            path = "/health"
            port = 8000
          }
          initial_delay_seconds = 10
          timeout_seconds = 5
          period_seconds = 10
          failure_threshold = 3
        }
        
        liveness_probe {
          http_get {
            path = "/health"
            port = 8000
          }
          initial_delay_seconds = 30
          timeout_seconds = 5
          period_seconds = 30
          failure_threshold = 3
        }
      }
    }
  }
  
  traffic {
    percent         = 100
    latest_revision = true
  }
  
  depends_on = [
    google_project_service.apis,
    google_sql_database_instance.postgres
  ]
}

# Make Cloud Run service publicly accessible
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.url_shortener.name
  location = google_cloud_run_service.url_shortener.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Outputs
output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_service.url_shortener.status[0].url
}

output "database_connection_name" {
  description = "Connection name for the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.cloud_run_sa.email
}