terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" { region = var.region }

# ============================================================================
# 1. SURICATA RULES
# ============================================================================

data "external" "suricata_info" {
  program = ["aws", "network-firewall", "describe-rule-group", "--rule-group-name", var.suricata_rg_name, "--type", "STATEFUL", "--query", "{ARN: RuleGroupResponse.RuleGroupArn, Token: UpdateToken}", "--output", "json"]
}

resource "local_file" "apply_suricata" {
  filename = "${path.module}/apply_suricata.sh"
  content  = <<EOT
#!/bin/bash
export MSYS_NO_PATHCONV=1
aws network-firewall update-rule-group \
  --rule-group-arn "${data.external.suricata_info.result.ARN}" \
  --update-token "${data.external.suricata_info.result.Token}" \
  --region "${var.region}" \
  --rule-group '{
    "RulesSource": {
      "RulesString": ${jsonencode(replace(trimspace(local.combined_suricata_rules), "http", "tcp"))}
    },
    "StatefulRuleOptions": {
      "RuleOrder": "STRICT_ORDER"
    }
  }'
EOT
}

resource "null_resource" "update_suricata" {
  triggers = { rules_hash = sha256(local.combined_suricata_rules) }
  depends_on = [local_file.apply_suricata]
  provisioner "local-exec" {
    interpreter = ["bash"]
    command     = "./apply_suricata.sh"
    #command = "bash ./apply_suricata.sh" - need to Use this line for gitlab linux based runner
  }
}

# ============================================================================
# 2. DOMAIN ALLOWLIST
# ============================================================================

data "external" "domain_info" {
  program = ["aws", "network-firewall", "describe-rule-group", "--rule-group-name", var.domain_rg_name, "--type", "STATEFUL", "--query", "{ARN: RuleGroupResponse.RuleGroupArn, Token: UpdateToken}", "--output", "json"]
}

resource "local_file" "apply_domains" {
  filename = "${path.module}/apply_domains.sh"
  content  = <<EOT
#!/bin/bash
export MSYS_NO_PATHCONV=1
aws network-firewall update-rule-group \
  --rule-group-arn "${data.external.domain_info.result.ARN}" \
  --update-token "${data.external.domain_info.result.Token}" \
  --region "${var.region}" \
  --rule-group '{
    "RulesSource": {
      "RulesSourceList": {
        "Targets": ${jsonencode(local.allowed_domains)},
        "TargetTypes": ["TLS_SNI", "HTTP_HOST"],
        "GeneratedRulesType": "ALLOWLIST"
      }
    },
    "StatefulRuleOptions": {
      "RuleOrder": "STRICT_ORDER"
    }
  }'
EOT
}

resource "null_resource" "update_domains" {
  triggers = { rules_hash = sha256(join(",", local.allowed_domains)) }
  depends_on = [local_file.apply_domains]
  provisioner "local-exec" {
    interpreter = ["bash"]
    command     = "./apply_domains.sh"
  }
}

# ============================================================================
# 3. 5-TUPLE RULES
# ============================================================================

data "external" "five_tuple_info" {
  program = ["aws", "network-firewall", "describe-rule-group", "--rule-group-name", var.five_tuple_rg_name, "--type", "STATEFUL", "--query", "{ARN: RuleGroupResponse.RuleGroupArn, Token: UpdateToken}", "--output", "json"]
}

resource "local_file" "apply_five_tuple" {
  filename = "${path.module}/apply_five_tuple.sh"
  content  = <<EOT
#!/bin/bash
export MSYS_NO_PATHCONV=1
aws network-firewall update-rule-group \
  --rule-group-arn "${data.external.five_tuple_info.result.ARN}" \
  --update-token "${data.external.five_tuple_info.result.Token}" \
  --region "${var.region}" \
  --rule-group '{
    "RulesSource": {
      "StatefulRules": ${local.five_tuple_json}
    },
    "StatefulRuleOptions": {
      "RuleOrder": "STRICT_ORDER"
    }
  }'
EOT
}

resource "null_resource" "update_five_tuple" {
  triggers = { rules_hash = sha256(local.five_tuple_json) }
  depends_on = [local_file.apply_five_tuple]
  provisioner "local-exec" {
    interpreter = ["bash"]
    command     = "./apply_five_tuple.sh"
  }
}