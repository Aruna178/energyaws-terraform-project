resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = var.public_ip
    zone_id                = data.aws_elb_service_account.main.zone_id
    evaluate_target_health = true
  }
}

data "aws_elb_service_account" "main" {}

output "dns_record" {
  value = aws_route53_record.app.name
}

