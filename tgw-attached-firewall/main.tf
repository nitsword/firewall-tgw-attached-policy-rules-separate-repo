terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.5"
    }
  }
}


provider "aws" {
  region = var.region
}


# Module for Suricata Rules
module "suricata_rules" {
  source                = "./modules/suricata_rules"
  environment           = var.environment
  application           = var.application
  region                = var.region
  env                   = var.env
  base_tags             = var.base_tags
  firewall_policy_name  = var.firewall_policy_name
  enable_suricata_rules = var.enable_suricata_rules
  stateful_rule_order       = var.stateful_rule_order

  home_net_cidrs       = ["10.0.0.0/8"] # Example CIDR, will be overridden by rule_ip_sets provided in firewall-rules-update repo.
  suricata_rg_capacity = var.suricata_rg_capacity
  rules_string         = "# Initialized by Repo 1 - Managed by Repo 2"
}

# Module for Domain List Rules
module "domain_rules" {
  source                    = "./modules/domain_list_rules"
  environment               = var.environment
  application               = var.application
  region                    = var.region
  env                       = var.env
  base_tags                 = var.base_tags
  firewall_policy_name      = var.firewall_policy_name
  enable_domain_allowlist   = var.enable_domain_allowlist
  domain_rg_capacity        = var.domain_rg_capacity
  stateful_rule_order       = var.stateful_rule_order
  priority_domain_allowlist = var.priority_domain_allowlist
  domain_list               = ["initial.placeholder.com"]
}

# Module for 5-Tuple Rules
module "five_tuple_rules" {
  source                 = "./modules/five_tuple_rules"
  environment            = var.environment
  application            = var.application
  region                 = var.region
  env                    = var.env
  base_tags              = var.base_tags
  firewall_policy_name   = var.firewall_policy_name
  five_tuple_rg_capacity = var.five_tuple_rg_capacity
  stateful_rule_order    = var.stateful_rule_order
  priority_five_tuple    = var.priority_five_tuple
  enable_5tuple_rules    = var.enable_5tuple_rules
  # Providing one dummy rule to satisfy the AWS API requirement
  five_tuple_rules = [{
    action           = "PASS"
    protocol         = "TCP"
    source           = "192.0.2.0/32" # Documentation/Dummy IP
    source_port      = "ANY"
    destination      = "192.0.2.1/32"
    destination_port = "ANY"
    direction        = "FORWARD"
    sid              = 1
  }]
}

# Firewall Policy Module
module "firewall_policy_conf" {
  source               = "./modules/firewall_policy_conf"
  environment          = var.environment
  application          = var.application
  region               = var.region
  env                  = var.env
  base_tags            = var.base_tags
  firewall_policy_name = var.firewall_policy_name
  stateful_rule_order  = var.stateful_rule_order

  domain_group_arn     = try(module.domain_rules.rule_group_arn, null)
  five_tuple_group_arn = module.five_tuple_rules.rule_group_arn
  suricata_group_arn   = try(module.suricata_rules.rule_group_arn, null)

  stateful_rule_group_arns    = var.stateful_rule_group_arns
  stateful_rule_group_objects = var.stateful_rule_group_objects
  priority_domain_allowlist   = var.priority_domain_allowlist
  priority_five_tuple         = var.priority_five_tuple
  priority_suricata           = var.priority_suricata
}

module "firewall" {
  source                = "./modules/firewall"
  application           = var.application
  environment           = var.environment
  region                = var.region
  env                   = var.env
  base_tags             = var.base_tags
  firewall_name         = var.firewall_name
  firewall_policy_name  = var.firewall_policy_name
  firewall_policy_arn   = module.firewall_policy_conf.firewall_policy_arn
  transit_gateway_id    = var.transit_gateway_id
  availability_zone_ids = var.availability_zone_ids
  depends_on = [
    module.secure_s3_bucket,
    module.firewall_policy_conf
  ]
}

module "secure_s3_bucket" {
  source                  = "./modules/s3_bucket"
  application             = var.application
  environment             = var.environment
  env                     = var.env
  base_tags               = var.base_tags
  # bucket_name             = var.bucket_name
  bucket_name_segment     = var.bucket_name
  existing_s3_bucket_name = var.existing_s3_bucket_name
  allowed_principal_arns  = var.s3_allowed_principals
}

# Configure Logging
resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = module.firewall.firewall_arn

  logging_configuration {
    #Alert Logs (Traffic matching DROP, ALERT, or REJECT rules)
    log_destination_config {
      log_destination = {
        bucketName = module.secure_s3_bucket.bucket_id
        prefix     = "alerts"
      }
      log_destination_type = "S3"
      log_type             = "ALERT"
    }
    #  TLS Logs (Encryption Handshake Events)
    log_destination_config {
      log_destination = {
        bucketName = module.secure_s3_bucket.bucket_id
        prefix     = "tls"
      }
      log_destination_type = "S3"
      log_type             = "TLS"
    }
    # Flow Logs (Standard network traffic metadata)
    log_destination_config {
      log_destination = {
        bucketName = module.secure_s3_bucket.bucket_id
        prefix     = "flow"
      }
      log_destination_type = "S3"
      log_type             = "FLOW"
    }
  }
}

