locals {
  # Dynamic Path Construction
  rules_base_path = "rule_config/${var.env}/"

  # ---------------------------------------------------------------------------
  # DOMAIN LIST RULES: Merging multiple CSVs
  # ---------------------------------------------------------------------------
  domain_files = fileset(path.module, "${local.rules_base_path}/domain_list_rules/*.csv")

  # Decode all files and flatten into a single list of maps
  all_domain_data = flatten([
    for f in local.domain_files : csvdecode(file("${path.module}/${f}"))
  ])

  allowed_domains = distinct([
    for d in local.all_domain_data : trimspace(d.domain)
    if lookup(d, "action", "") != "" && upper(trimspace(d.action)) == "ALLOW"
  ])

  # ---------------------------------------------------------------------------
  # 5-TUPLE RULES: Merging multiple CSVs 
  # ---------------------------------------------------------------------------
  tuple_files = fileset(path.module, "${local.rules_base_path}/five_tuple_rules/*.csv")

  all_tuple_data = flatten([
    for f in local.tuple_files : csvdecode(file("${path.module}/${f}"))
  ])

  five_tuple_rules = [
    for i, r in local.all_tuple_data : {
      action           = upper(lookup(r, "action", "PASS"))
      protocol         = upper(lookup(r, "protocol", "TCP"))
      source           = lookup(r, "source", "ANY") == "" ? "ANY" : upper(r.source)
      source_port      = lookup(r, "source_port", "ANY") == "" ? "ANY" : upper(r.source_port)
      destination      = lookup(r, "destination", "ANY") == "" ? "ANY" : upper(r.destination)
      destination_port = lookup(r, "destination_port", "ANY") == "" ? "ANY" : upper(r.destination_port)
      direction        = "FORWARD"
      # Generates unique SIDs starting from 1000001 based on index in merged list
      sid = tostring(lookup(r, "sid", 1000001 + i))
    }
  ]

  # This converts the 'five_tuple_rules' list above into a JSON string for the CLI
  five_tuple_json = jsonencode([
    for r in local.five_tuple_rules : {
      Action = r.action
      Header = {
        Protocol        = r.protocol
        Source          = r.source
        SourcePort      = r.source_port
        Destination     = r.destination
        DestinationPort = r.destination_port
        Direction       = r.direction
      }
      RuleOptions = [{
        Keyword  = "sid"
        Settings = [r.sid]
      }]
    }
  ])


  # ---------------------------------------------------------------------------
  # Suricata RULES: Merging multiple CSVs
  # ---------------------------------------------------------------------------
  # 1. Find all rule files
  suricata_files = fileset(path.module, "${local.rules_base_path}/suricata_rules/*.csv")

  #Load the CSV data
  suricata_raw_data = flatten([
    for f in local.suricata_files : csvdecode(file(f))
  ])

  # 2. Convert each row into a Suricata Rule String
  # Pattern: action protocol source_ip source_port direction destination_ip destination_port (msg:"CSRE_NO"; sid:SID;)
  suricata_rule_list = [
    for row in local.suricata_raw_data :
    format("%s %s %s %s %s %s %s (msg:\"%s | %s | %s\"; sid:%s;)",
      row.action,
      row.protocol,
      row.source_ip == "HOME_NET" ? "$HOME_NET" : row.source_ip,
      row.source_port,
      row.direction,
      replace(row.destination_ip, "HOME_NET", "$HOME_NET"),
      row.destination_port,
      row.rule_name,
      row.message,
      row.csre_no,
      row.sid
    )
  ]

  # 2. Read and join all files into a single string
  #  join("\n", ...) to ensure each file's rules start on a new line
  combined_suricata_rules = join("\n", local.suricata_rule_list)
}