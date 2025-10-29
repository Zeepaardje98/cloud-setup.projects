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

data "terraform_remote_state" "do-remote-state" {
  backend = "s3"
  config = {
    endpoints = {
      s3 = "https://${var.region}.digitaloceanspaces.com"
    }
    bucket                      = "${var.bucket_name}"
    key                         = "foundation/digitalocean-remote-state/terraform.tfstate"
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

  repository_name        = "example-project-1"
  repository_description = "Example project 1 repository for testing of cloud-setup.projects pipeline"
  repository_visibility  = "private"
  is_template            = false
  template_owner         = ""
  template_repository    = ""

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

# Overwrite some private variables from the organization secrets by placing them in the repository secrets, in case
# the github plan does not support the use of organisation secrets in private repositories. You can remove this part
# if you are using a github plan that does support this feature.
resource "github_actions_secret" "spaces_secret_key_ci" {
  repository    = module.github_repo.repository_name
  secret_name   = "DO_STATE_BUCKET_SECRET_KEY"
  plaintext_value = data.terraform_remote_state.do-remote-state.outputs.bucket_spaces_secret_key_ci
}
