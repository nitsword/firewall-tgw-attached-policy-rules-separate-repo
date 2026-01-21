region                = "us-east-1"
transit_gateway_id    = "tgw-0c61971f6a5e960d9"
availability_zone_ids = ["use1-az1", "use1-az2", "use1-az4"]

application = "ntw"
env         = "dev" # Is being used for naming convention
environment = "Non-production::Dev" # For tagging purpose only

# --- Firewall Policy Configuration ---
firewall_name        = "inspection-firewall-dev"
firewall_policy_name = "inspection-firewall-policy-dev"
stateful_rule_order  = "STRICT_ORDER"

# --- Capacities & Priorities ---
priority_domain_allowlist = 10 
priority_five_tuple       = 20
priority_suricata         = 30

enable_domain_allowlist = true
enable_5tuple_rules     = true
enable_suricata_rules   = true

domain_rg_capacity      = 1000
five_tuple_rg_capacity   = 1000 
suricata_rg_capacity     = 2000

# --- External Rule Groups ---
stateful_rule_group_arns    = []
stateful_rule_group_objects = []

# --- S3 Bucket Configuration ---

# --- S3 Bucket Name ---
bucket_name = "tmo-firewall-logs-bucket-test"

existing_s3_bucket_name = ""  # Leave empty to create a new bucket

# --- AWS iam role to grant access on s3 bucket---
s3_allowed_principals = [
  "arn:aws:iam::359416636780:user/terraform-test"
]