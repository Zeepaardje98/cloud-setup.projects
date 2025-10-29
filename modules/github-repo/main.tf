# Create the GitHub repository
resource "github_repository" "this" {
  name        = var.repository_name
  description = var.repository_description

  visibility = var.repository_visibility
  is_template = var.is_template

  template {
    owner      = var.template_owner
    repository = var.template_repository
  }
}

resource "github_branch" "staging" {
  repository    = var.repository_name
  branch        = "staging"
  source_branch = "main"
}

resource "github_branch" "production" {
  repository    = var.repository_name
  branch        = "production"
  source_branch = "staging"
  
  depends_on = [github_branch.staging]
}

# Add team access to the repository (from input map)
resource "github_team_repository" "this" {
  for_each   = var.repository_teams
  team_id    = each.value.team_id
  repository = github_repository.this.name
  permission = each.value.permission
}

# Create repository environments with team reviewers (configurable)
resource "github_repository_environment" "this" {
  for_each   = var.environment_review_teams
  repository = var.repository_name
  environment = each.key

  dynamic "reviewers" {
    for_each = length(each.value) > 0 ? [1] : []
    content {
      teams = each.value
    }
  }

  depends_on = [github_team_repository.this]
}

# Branch protection for main branch (basic protection)
resource "github_branch_protection" "main" {
  repository_id = var.repository_name
  pattern       = "main"

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }

  required_status_checks {
    strict   = true
    contexts = ["test"]
  }

  enforce_admins = false
}

# Branch protection for staging branch (basic protection)
resource "github_branch_protection" "staging" {
  repository_id = var.repository_name
  pattern       = "staging"

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }

  required_status_checks {
    strict   = true
    contexts = ["test"]
  }

  enforce_admins = false
  
  depends_on = [github_branch.staging]
}

# Branch protection for production branch (most restrictive - DevOps only)
resource "github_branch_protection" "production" {
  repository_id = var.repository_name
  pattern       = "production"

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }

  required_status_checks {
    strict   = true
    contexts = ["test"]
  }

  enforce_admins = false
  
  depends_on = [github_branch.production]
}