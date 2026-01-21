resource "aws_networkfirewall_rule_group" "suricata_rule_group" {
  count    = var.enable_suricata_rules ? 1 : 0
  name     = "${var.application}-${var.env}-suricata-rg-${var.region}"
  capacity = var.suricata_rg_capacity
  type     = "STATEFUL"

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = var.home_net_cidrs
        }
      }
    }

    rules_source {
      # This acts as a placeholder for the first deployment.
      # Repo 2 will overwrite this text immediately.
      rules_string = var.rules_string 
    }

    stateful_rule_options {
      rule_order = var.stateful_rule_order
    }
  }

  # This allows Repo 2 to update the rules without Repo 1 
  lifecycle {
    ignore_changes = [
      rule_group[0].rules_source[0].rules_string,
      tags["Creation Date"] # Optional: prevents drift from the timestamp() function
    ]
  }

  tags = merge({
    Name            = "${var.application}-${var.env}-suricata-rg-${var.region}"
    "Resource Type" = "suricata-rg"
    "Creation Date" = timestamp()
    "Environment"   = var.environment
    "Application"   = var.application
    "Created by"    = "Cloud Network Team"
    "Region"        = var.region
  }, var.base_tags)
}