# --- Global Settings ---
variable "region" {
  description = "The AWS region where the firewall resides."
  type        = string
}

variable "application" {
  description = "The application shortname (e.g., ntw)."
  type        = string
}

variable "env" {
  description = "The environment stage (e.g., dev, prod)."
  type        = string
}

# --- Directory Targeting ---
variable "rule_set_env" {
  description = "The folder name inside rules_config/ to look for CSVs (e.g., dev)."
  type        = string
}

# --- Rule Group Names (Targets for the AWS CLI) ---
# These names must match the 'name' attribute of the resources in Repo 1 exactly.

variable "suricata_rg_name" {
  description = "The exact name of the Suricata rule group in AWS."
  type        = string
}

variable "domain_rg_name" {
  description = "The exact name of the Domain Allowlist rule group in AWS."
  type        = string
}

variable "five_tuple_rg_name" {
  description = "The exact name of the 5-Tuple rule group in AWS."
  type        = string
}