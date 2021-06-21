locals {
  # terragrunt users have to provide `records` as jsonencode()'d string.
  # See details: https://github.com/gruntwork-io/terragrunt/issues/1211
  records = try(jsondecode(var.records), var.records)

  # convert from list to map with unique keys
  recordsets = { for rs in local.records : join(" ", compact(["${rs.name} ${rs.type}", lookup(rs, "set_identifier", "")])) => rs }
}

data "aws_route53_zone" "this" {
  count = var.create && (var.zone_id != null || var.zone_name != null) ? 1 : 0

  zone_id      = var.zone_id
  name         = var.zone_name
  private_zone = var.private_zone
}

resource "aws_route53_record" "this" {
  for_each = var.create && (var.zone_id != null || var.zone_name != null) ? local.recordsets : {}

  zone_id = data.aws_route53_zone.this[0].zone_id

  name            = each.value.name != "" ? "${each.value.name}.${data.aws_route53_zone.this[0].name}" : data.aws_route53_zone.this[0].name
  type            = each.value.type
  ttl             = lookup(each.value, "ttl", null)
  records         = lookup(each.value, "records", null)
  set_identifier  = lookup(each.value, "set_identifier", null)
  health_check_id = lookup(each.value, "health_check_id", null)

  dynamic "alias" {
    for_each = length(keys(lookup(each.value, "alias", {}))) == 0 ? [] : [true]

    content {
      name                   = each.value.alias.name
      zone_id                = try(each.value.alias.zone_id, data.aws_route53_zone.this[0].zone_id)
      evaluate_target_health = lookup(each.value.alias, "evaluate_target_health", false)
    }
  }

  dynamic "failover_routing_policy" {
    for_each = length(keys(lookup(each.value, "failover_routing_policy", {}))) == 0 ? [] : [true]

    content {
      type = each.value.failover_routing_policy.type
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = length(keys(lookup(each.value, "weighted_routing_policy", {}))) == 0 ? [] : [true]

    content {
      weight = each.value.weighted_routing_policy.weight
    }
  }
}
