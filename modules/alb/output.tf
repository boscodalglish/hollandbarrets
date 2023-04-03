output "tg_public_arn" {
  value = aws_alb_target_group.public_http.arn
}

output "sg_alb_public_id" {
  value = aws_security_group.public_alb_sg.id
}

output "alb_public_arn" {
  value = aws_alb_target_group.public_http.arn
}

output "sg_alb_private_id" {
  value = aws_security_group.private_alb_sg.id
}

output "alb_private_arn" {
  value = aws_alb_target_group.private_http.arn
}
