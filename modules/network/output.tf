output "security_group_Private_SG_allow_tls_id" {
  description = "ID for Private Main SG"
  value       = aws_security_group.Private_SG_allow_tls.id
}

output "security_group_Public_SG_allow_tls_id" {
  description = "ID for Public Main SG"
  value       = aws_security_group.Public_SG_allow_tls.id
}