
variable "tags" {}
variable "public_subnets" {
    type = list
}
variable "public_sg_alb" {}
variable "target_group_arns_public" {
}

variable "private_subnets" {
    type = list
}
variable "private_sg_alb" {}
variable "target_group_arns_private" {
}
variable "enable_public_subnets" {}
variable "enable_private_subnets" {}

variable "db_subnets" {
    type = list
}
variable "db_sg_ist" {}