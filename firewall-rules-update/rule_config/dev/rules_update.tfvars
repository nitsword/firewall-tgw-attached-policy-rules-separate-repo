region      = "us-east-1"
application = "ntw"
env         = "dev"
rule_set_env = "dev"

# Naming convention based on Repo 1(tgw-attached-firewall) code:
suricata_rg_name   = "ntw-dev-suricata-rg-us-east-1"
domain_rg_name     = "domain-allowlist-inspection-firewall-policy-dev"
five_tuple_rg_name = "five-tuple-rg-inspection-firewall-policy-dev"

# Mention the protocols to inspect.
target_types = ["TLS_SNI", "HTTP_HOST"]

# Define IP sets (rules variables)for Suricata rules
rule_ip_sets = {
  "HOME_NET"       = { definition = ["10.0.0.0/8"] }
  #"S3_IP_RANGE"    = { definition = ["52.216.0.0/15"] }
  #"INTERNAL_HOSTS" = { definition = ["10.1.2.3/32"] }
}