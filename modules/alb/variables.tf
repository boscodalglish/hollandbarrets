
variable "name" {
    description = "Name of the project"
}
variable "vpc_id" {
    description = "VPC ID"
}
variable "public_subnets" {
    description = "List of all public subnets in VPC"
    type = list
}
variable "private_subnets" {
    description = "List of all private subnets in VPC"
    type = list
}