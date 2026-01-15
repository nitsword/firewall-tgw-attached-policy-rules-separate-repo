resource "aws_networkfirewall_rule_group" "domain_allowlist" {
  count = var.enable_domain_allowlist ? 1 : 0
  
  name         = "domain-allowlist-${var.firewall_policy_name}"
  description  = "Domain allowlist rule group (AWS-managed FQDN filtering)."
  type         = "STATEFUL"
  capacity     = var.domain_rg_capacity

  rule_group {
    stateful_rule_options {
      rule_order = var.stateful_rule_order
    }
    rules_source {
      rules_source_list {
        # Initial list from Repo 1. Repo 2 will manage this list moving forward.
        targets              = var.domain_list
        target_types         = ["TLS_SNI", "HTTP_HOST"]
        generated_rules_type = "ALLOWLIST"
      }
    }
  }

  # CRITICAL: Prevents Repo 1 from reverting domain changes made by Repo 2
  lifecycle {
    ignore_changes = [
      rule_group[0].rules_source[0].rules_source_list[0].targets,
      tags["Creation Date"]
    ]
  }

  tags = merge({
    Name            = "${var.application}-${var.env}-domain-allow-rg-${var.region}"
    "Resource Type" = "domain-allow-rg"
    "Creation Date" = timestamp()
    "Environment"   = var.environment
    "Application"   = var.application
    "Created by"    = "Cloud Network Team"
    "Region"        = var.region
  }, var.base_tags)
}