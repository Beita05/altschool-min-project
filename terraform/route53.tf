resource "aws_route53_zone" "main" {
  name = "beita.me"
}

resource "aws_route53_zone" "sub" {
  name = "terraform-test.beita.me"
}

resource "aws_route53_record" "sub-ns" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "terraform-test.beita.me"
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.sub.name_servers
}