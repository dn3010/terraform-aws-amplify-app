locals {
  basic_auth_creds = try(base64encode("${var.basic_auth_username}:${var.basic_auth_password}"), null)
}

module "master_branch_label" {
  source  = "cloudposse/label/null"
  version = "0.24.1"

  attributes = concat(var.attributes, ["master"])

  context = module.this.context
}

module "develop_branch_label" {
  source  = "cloudposse/label/null"
  version = "0.24.1"

  attributes = concat(var.attributes, ["develop"])

  context = module.this.context
}

data "aws_iam_policy_document" "assume_role" {
  count = module.this.enabled && var.amplify_service_role_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["amplify.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default" {
  count = module.this.enabled && var.amplify_service_role_enabled ? 1 : 0

  name                = module.this.id
  assume_role_policy  = join("", data.aws_iam_policy_document.assume_role.*.json)
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  tags                = module.this.tags
}

resource "aws_amplify_app" "this" {
  name                     = module.this.id
  description              = var.description != null ? var.description : "Amplify App for the github.com/${var.organization}/${var.repo} project."
  repository               = "https://github.com/${var.organization}/${var.repo}"
  access_token             = var.gh_access_token
  enable_branch_auto_build = true
  build_spec               = var.build_spec_content != "" ? var.build_spec_content : null
  environment_variables    = var.global_environment_variables
  iam_service_role_arn     = var.amplify_service_role_enabled ? aws_iam_role.default[0].arn : null
  tags                     = module.this.tags

  enable_basic_auth      = var.enable_basic_auth_globally
  basic_auth_credentials = local.basic_auth_creds

  dynamic "custom_rule" {
    for_each = var.custom_rules
    iterator = rule

    content {
      source    = rule.value.source
      target    = rule.value.target
      status    = rule.value.status
      condition = lookup(rule.value, "condition", null)
    }
  }

  lifecycle {
    ignore_changes = [platform, custom_rule]
  }
}

resource "aws_amplify_branch" "master" {
  count                   = var.master_environment_enabled ? 1 : 0
  app_id                  = aws_amplify_app.this.id
  branch_name             = var.master_branch_name
  display_name            = module.master_branch_label.id
  tags                    = module.master_branch_label.tags
  backend_environment_arn = var.master_backend_environment_enabled ? aws_amplify_backend_environment.master[0].arn : null

  environment_variables = var.master_environment_variables

  enable_basic_auth      = var.enable_basic_auth_on_master
  basic_auth_credentials = local.basic_auth_creds

  lifecycle {
    ignore_changes = [framework]
  }
}

resource "aws_amplify_branch" "develop" {
  count                       = var.develop_environment_enabled ? 1 : 0
  app_id                      = aws_amplify_app.this.id
  branch_name                 = var.develop_branch_name
  display_name                = module.develop_branch_label.id
  enable_pull_request_preview = var.develop_pull_request_preview
  tags                        = module.develop_branch_label.tags
  backend_environment_arn     = var.develop_backend_environment_enabled ? aws_amplify_backend_environment.develop[0].arn : null

  environment_variables = var.develop_environment_variables

  enable_basic_auth      = var.enable_basic_auth_on_develop
  basic_auth_credentials = local.basic_auth_creds

  lifecycle {
    ignore_changes = [framework]
  }
}

resource "aws_amplify_backend_environment" "master" {
  count            = var.master_backend_environment_enabled ? 1 : 0
  app_id           = aws_amplify_app.this.id
  environment_name = var.master_branch_name
}

resource "aws_amplify_backend_environment" "develop" {
  count            = var.develop_backend_environment_enabled ? 1 : 0
  app_id           = aws_amplify_app.this.id
  environment_name = var.develop_branch_name
}

resource "aws_amplify_domain_association" "master" {
  count = var.master_domain_name != "" ? 1 : 0

  app_id      = aws_amplify_app.this.id
  domain_name = var.master_domain_name

  sub_domain {
    branch_name = var.master_branch_name
    prefix      = var.master_subdomain_prefix
  }
}

resource "aws_amplify_domain_association" "develop" {
  count = var.develop_domain_name != "" ? 1 : 0

  app_id      = aws_amplify_app.this.id
  domain_name = var.develop_domain_name

  sub_domain {
    branch_name = var.develop_branch_name
    prefix      = var.develop_subdomain_prefix
  }
}

resource "aws_amplify_webhook" "master" {
  count       = var.master_environment_enabled ? 1 : 0
  app_id      = aws_amplify_app.this.id
  branch_name = var.master_branch_name
  description = "trigger-master"

  # NOTE: We trigger the webhook via local-exec so as to kick off the first build on creation of Amplify App.
  provisioner "local-exec" {
    command = "curl -X POST -d {} '${aws_amplify_webhook.master[count.index].url}&operation=startbuild' -H 'Content-Type:application/json'"
  }
}

resource "aws_amplify_webhook" "develop" {
  count       = var.develop_environment_enabled ? 1 : 0
  app_id      = aws_amplify_app.this.id
  branch_name = var.develop_branch_name
  description = "trigger-develop"

  # NOTE: We trigger the webhook via local-exec so as to kick off the first build on creation of Amplify App.
  provisioner "local-exec" {
    command = "curl -X POST -d {} '${aws_amplify_webhook.develop[count.index].url}&operation=startbuild' -H 'Content-Type:application/json'"
  }
}
