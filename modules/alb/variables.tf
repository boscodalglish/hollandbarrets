
variable "name" {}
variable "vpc_id" {}
variable "public_subnets" {
    type = list
}
variable "private_subnets" {
    type = list
}