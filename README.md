
# Holland and Barrett Test Project

This is a test project for Holland and Barrett Platform Team.




## Environment Variables

To run this project, you will need to add the following environment variables to your .env file

`secret_key`

`access_key`


## Deployment

To deploy this project locally run the following Terraform commands, you need to create enviroment variables as described in Environment variables section in tfvars file.

```bash
  terraform init
  terraform plan
  terraform apply
```


## Modules

### VPC
The VPC module is used to create the VPC,route tables, IGW, NatGateway, Private subnets, Public Subnets, Database Subnets.

Below required variables are used to enable proper functioning of VPC module

```bash
  cidr
  private_subnets
  public_subnets
  database_subnets
  azs
```

You can have more details in below 

[VPC module](https://github.com/terraform-aws-modules/terraform-aws-vpc)

### Autoscaler
The Autoscaler module is used to create instances in private, public and database subnets. Based on VPC variables it creates a autoscaling group in VPC.

Below variables are used to enable public, private and database subnets in VPC

```bash
  enable_public_subnets
  enable_private_subnets
  enable_db_subnets
```

[Autoscaling module](https://github.com/terraform-aws-modules/terraform-aws-autoscaling)

### ALB
The ALB module is used to create public ALB and Private ALB and its associated Security groups.

### Network
The network module creates instance Security groups for private public and database subnets
