
variable "public_subnets" {
    description = "List of all public subnets in VPC"
    type = list
}
variable "public_sg_ist" {
    description = "List of security groups attached to public subnet"
}
variable "target_group_arns_public" {
    description = "Traget group attached to the public instances"
}

variable "private_subnets" {
    description = "List of all private subnets in VPC"
    type = list
}
variable "private_sg_ist" {
    description = "List of security groups attached to private subnet"
}
variable "target_group_arns_private" {
    description = "Traget group attached to the public instances"
}
variable "db_subnets" {
    description = "List of database subnets attached to private subnet"
    type = list
}
variable "db_sg_ist" {
    description = "List of security groups attached to private subnet"
}
variable "enable_public_subnets" {
    description = "Enable public subnets, accepts boolens values"
}
variable "enable_private_subnets" {
    description = "Enable private subnets, accepts boolens values"
}
variable "enable_db_subnets" {
    description = "Enable db subnets, accepts boolens values"
}

variable "html_data" {
    description = "Content to be displayed"
}