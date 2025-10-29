terraform {
  required_version = ">= 1.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  backend "s3" {}
}

provider "github" {
  token = var.github_repo_token
  owner = var.github_organization
}

# Read outputs from the GitHub organization state (02-github-org-config)
data "terraform_remote_state" "github_org_config" {
  backend = "s3"
  config = {
    endpoints = {
      s3 = "https://${var.region}.digitaloceanspaces.com"
    }
    bucket                      = var.bucket_name
    key                         = "foundation/github-org-config/terraform.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}

module "github_repo" {
  source = "../../modules/github-repo"

  repository_name        = var.repository_name
  repository_description = var.repository_description
  repository_visibility  = var.repository_visibility
  is_template            = var.is_template
  template_owner         = var.template_owner
  template_repository    = var.template_repository

  # Grant teams repository access
  repository_teams = {
    devops_gouda = {
      team_id    = data.terraform_remote_state.github_org_config.outputs.devops_gouda_team_id
      permission = "push"
    }
    development_brie = {
      team_id    = data.terraform_remote_state.github_org_config.outputs.development_brie_team_id
      permission = "push"
    }
    qa_parmesan = {
      team_id    = data.terraform_remote_state.github_org_config.outputs.qa_parmesan_team_id
      permission = "pull"
    }
  }

  # Require approvals from DevOps (production) and none for staging
  environment_review_teams = {
    staging    = []
    production = [
      data.terraform_remote_state.github_org_config.outputs.devops_gouda_team_id
    ]
  }
}


