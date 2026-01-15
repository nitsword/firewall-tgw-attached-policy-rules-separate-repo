output "rule_group_arn" {
  value = length(aws_networkfirewall_rule_group.suricata_rule_group) > 0 ? aws_networkfirewall_rule_group.suricata_rule_group[0].arn : null
}