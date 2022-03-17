output "arn" {
  description = "The ARN of the main Amplify resource."
  value       = aws_amplify_app.this.arn
}

output "default_domain" {
  description = "The amplify domain (non-custom)."
  value       = aws_amplify_app.this.default_domain
}

output "master_domain_association_arn" {
  description = "The ARN of the domain association resource."
  value       = var.master_domain_name == "" ? null : join("", concat([""], aws_amplify_domain_association.master.*.arn))
}

output "develop_domain_association_arn" {
  description = "The ARN of the domain association resource."
  value       = var.master_domain_name == "" ? null : join("", concat([""], aws_amplify_domain_association.develop.*.arn))
}

output "custom_domains" {
  description = "List of custom domains that are associated with this resource (if any)."
  value = var.master_domain_name == "" ? [] : [
    var.domain_name,
    "${var.master_subdomain_prefix}.${var.master_domain_name}",
    "${var.develop_subdomain_prefix}.${var.develop_domain_name}",
  ]
}

output "master_webhook_arn" {
  count       = var.master_environment_enabled ? 1 : 0
  description = "The ARN of the master webhook."
  value       = aws_amplify_webhook.master[count.index].arn
}

output "master_webhook_url" {
  count       = var.master_environment_enabled ? 1 : 0
  description = "The URL of the master webhook."
  value       = aws_amplify_webhook.master[count.index].url
}

output "develop_webhook_arn" {
  count       = var.develop_environment_enabled ? 1 : 0
  description = "The ARN of the develop webhook."
  value       = aws_amplify_webhook.develop[count.index].arn
}

output "develop_webhook_url" {
  count       = var.develop_environment_enabled ? 1 : 0
  description = "The URL of the develop webhook."
  value       = aws_amplify_webhook.develop[count.index].url
}
