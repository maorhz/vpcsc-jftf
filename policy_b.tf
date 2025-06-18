# This HCL file (terraform plan) is unsupported and does not affiliate with any Google commercial nor open-source project, product, or service.
# Adject as needed and use this plan with cautious as a template or example to implement policy using gcp vpc service controls.

# ------------------------------------------------------------------------------
# Provider Configuration
# ------------------------------------------------------------------------------
# Ensure you have authenticated with Google Cloud.
# You can replace the project and region with your specific details.
provider "google" {
  project = "your-gcp-project-id"
  region  = "your-region" 
}

# ------------------------------------------------------------------------------
# Access Context Manager Policy
# ------------------------------------------------------------------------------
# This resource creates a new Access Context Manager Policy named "POLICY_B".
# You need to provide your organization ID.
resource "google_access_context_manager_access_policy" "access_policy" {
  parent = "organizations/your-organization-id" # CHANGE ORG ID
  title  = "POLICY_B"
}

# ------------------------------------------------------------------------------
# Service Perimeter
# ------------------------------------------------------------------------------
# This perimeter enforces the access levels on the specified resources and services.
resource "google_access_context_manager_service_perimeter" "jfrog_perimeter" {
  parent = google_access_context_manager_access_policy.access_policy.name
  name   = "${google_access_context_manager_access_policy.access_policy.name}/servicePerimeters/prmt_jfrog"
  title  = "prmt-jfrog"
  
  # Set perimeter type to regular and enforcement to enforced
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  
  status {
    # Protect the specified project
    resources = ["projects/p-prd-app2"]
    
    # Restrict access to Google Cloud Storage
    restricted_services = ["storage.googleapis.com"]
    
    # Apply both access levels to the perimeter.
    # The "AND" logic from your request is handled by how the access levels
    # themselves are defined. An inbound request must satisfy one of these levels.
    access_levels = [
      google_access_context_manager_access_level.any_sa_except_one_from_ip.name,
      google_access_context_manager_access_level.specific_sa_from_ip.name,
    ]
  }
}

# ------------------------------------------------------------------------------
# Access Level 1: Any SA (except high-priv) from a specific IP
# ------------------------------------------------------------------------------
# This access level grants access to any identity from the specified IP range,
# but it explicitly negates (denies) the highly priveledged service account/s.
resource "google_access_context_manager_access_level" "any_sa_except_one_from_ip" {
  parent = google_access_context_manager_access_policy.access_policy.name
  name   = "${google_access_context_manager_access_policy.access_policy.name}/accessLevels/anySaExceptOneFromIp"
  title  = "Any SA Except HPRIV From Specific IP"
  
  basic {
    combining_function = "AND"
    conditions {
      # Condition 1: Allow any request from the specified IP addresses.
      ip_subnetworks = ["44.202.22.235/32"]
    }
    conditions {
      # Condition 2: NEGATE (deny) the specific service account/s.
      # This means the condition is true for anyone *except* the highly privileged service accounts.
      negate  = true
      members = ["serviceAccount:sa1test@p-prd-app1.iam.gserviceaccount.com"]
    }
  }
}

# ------------------------------------------------------------------------------
# Access Level 2: Specific SA from a specific IP
# ------------------------------------------------------------------------------
# This access level grants access ONLY to the specified service account/s
# when the request originates from the specified IP addresses.
resource "google_access_context_manager_access_level" "specific_sa_from_ip" {
  parent = google_access_context_manager_access_policy.access_policy.name
  name   = "${google_access_context_manager_access_policy.access_policy.name}/accessLevels/specificSaFromIp"
  title  = "HPRIV SA From Specific IP"
  
  basic {
    conditions {
      ip_subnetworks = ["44.202.22.235/32"]
      members = [
        "serviceAccount:sa1test@p-prd-app1.iam.gserviceaccount.com"
      ]
    }
  }
}
