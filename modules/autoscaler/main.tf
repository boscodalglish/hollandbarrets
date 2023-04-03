locals {

  name              = "hb-project"
  region            = "eu-west-1"
  user_data_private = <<-EOT
    #!/bin/bash
    sudo apt-get update -y
    node -v
    echo "<html>"
    echo "<head>"
    echo "  <title>"
    echo "  The title of your page"
    echo "  </title>"
    echo "</head>"
    echo ""
    echo "<body>"
    echo "  Your page content goes here."
    echo "</body>"
    echo "</html>"
  EOT
  user_data_public  = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd.service
    sudo systemctl enable httpd.service
    sudo touch /var/www/html/index.html
    sudo chmod 777 /var/www/html/index.html
    cat <<'END_HTML' > /var/www/html/index.html
    <h1>Hello World!</h1>
    END_HTML
    sudo systemctl restart httpd.service
  EOT  
  user_data_db  = <<-EOT
    #!/bin/bash
    sudo apt-get update -y
    sudo curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    sudo apt-key list
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt update -y
    sudo apt install mongodb-org -y
    sudo systemctl start mongod.service
    sudo systemctl status mongod
  EOT
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "random_integer" "priority" {
  min = 1
  max = 50000
  keepers = {
    # Generate a new integer each time we switch to a new listener ARN
    user_data_public = local.user_data_public
  }
}

################################################################################
# Complete Public Autoscaling group
################################################################################

module "complete_public_asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  count  = var.enable_public_subnets ? 1 : 0
  # Autoscaling group
  name                            = "complete-${local.name}-public-${random_integer.priority.result}"
  use_name_prefix                 = false
  instance_name                   = "${local.name}-instance-public"
  ignore_desired_capacity_changes = false

  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  default_instance_warmup   = 300
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["${var.public_subnets[0]}", "${var.public_subnets[1]}", "${var.public_subnets[2]}"]

  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name        = "complete-${local.name}-public"
  launch_template_description = "Complete launch template example"
  update_default_version      = true

  image_id          = data.aws_ami.amazon-linux-2.image_id
  instance_type     = "t3.micro"
  user_data         = base64encode(local.user_data_public)
  ebs_optimized     = true
  enable_monitoring = true

  create_iam_instance_profile = true
  iam_role_name               = "complete-${local.name}"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Complete IAM role example"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # # Security group is set on the ENIs below
  security_groups = [var.public_sg_alb]

  target_group_arns = [var.target_group_arns_public]

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
      }
      }, {
      device_name = "/dev/sda1"
      no_device   = 1
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
      }
    }
  ]

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  cpu_options = {
    core_count       = 1
    threads_per_core = 1
  }

  credit_specification = {
    cpu_credits = "standard"
  }

  instance_market_options = {
    market_type = "spot"
  }

  maintenance_options = {
    auto_recovery = "default"
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 32
    instance_metadata_tags      = "enabled"
  }

  network_interfaces = [
    {
      delete_on_termination       = true
      description                 = "eth0"
      device_index                = 0
      associate_public_ip_address = true
      security_groups             = ["${var.public_sg_alb}"]
    }
  ]

  placement = {
    availability_zone = "${local.region}a"
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = merge({ WhatAmI = "Volume" })
    },
    {
      resource_type = "spot-instances-request"
      tags          = merge({ WhatAmI = "SpotInstanceRequest" })
    }
  ]

  # Autoscaling Schedule
  schedules = {
    # night = {
    #   min_size         = 0
    #   max_size         = 0
    #   desired_capacity = 0
    #   recurrence       = "0 18 * * 1-5" # Mon-Fri in the evening
    #   time_zone        = "Europe/Rome"
    # }

    # morning = {
    #   min_size         = 0
    #   max_size         = 1
    #   desired_capacity = 1
    #   recurrence       = "0 7 * * 1-5" # Mon-Fri in the morning
    # }

    # go-offline-to-celebrate-new-year = {
    #   min_size         = 0
    #   max_size         = 0
    #   desired_capacity = 0
    #   start_time       = "2031-12-31T10:00:00Z" # Should be in the future
    #   end_time         = "2032-01-01T16:00:00Z"
    # }
  }
  # Target scaling policy schedule based on average CPU load
  # scaling_policies = {
  #   avg-cpu-policy-greater-than-50 = {
  #     policy_type               = "TargetTrackingScaling"
  #     estimated_instance_warmup = 1200
  #     target_tracking_configuration = {
  #       predefined_metric_specification = {
  #         predefined_metric_type = "ASGAverageCPUUtilization"
  #       }
  #       target_value = 50.0
  #     }
  #   },
  # predictive-scaling = {
  #   policy_type = "PredictiveScaling"
  #   predictive_scaling_configuration = {
  #     mode                         = "ForecastAndScale"
  #     scheduling_buffer_time       = 10
  #     max_capacity_breach_behavior = "IncreaseMaxCapacity"
  #     max_capacity_buffer          = 10
  #     metric_specification = {
  #       target_value = 32
  #       predefined_scaling_metric_specification = {
  #         predefined_metric_type = "ASGAverageCPUUtilization"
  #         resource_label         = "testLabel"
  #       }
  #       predefined_load_metric_specification = {
  #         predefined_metric_type = "ASGTotalCPUUtilization"
  #         resource_label         = "testLabel"
  #       }
  #     }
  #   }
  # }
  # request-count-per-target = {
  #   policy_type               = "TargetTrackingScaling"
  #   estimated_instance_warmup = 120
  #   target_tracking_configuration = {
  #     predefined_metric_specification = {
  #       predefined_metric_type = "ALBRequestCountPerTarget"
  #       resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
  #     }
  #     target_value = 800
  #   }
  # }
}
# }


################################################################################
# Complete Private Autoscaling group
################################################################################

module "complete_private_asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  count  = var.enable_private_subnets ? 1 : 0
  # Autoscaling group
  name                            = "complete-${local.name}-private-${random_integer.priority.result}"
  use_name_prefix                 = false
  instance_name                   = "${local.name}-instance-private"
  ignore_desired_capacity_changes = false

  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  default_instance_warmup   = 300
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["${var.private_subnets[0]}", "${var.private_subnets[1]}", "${var.private_subnets[2]}"]

  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name        = "complete-${local.name}-private"
  launch_template_description = "Complete launch template example"
  update_default_version      = true

  image_id          = data.aws_ami.amazon-linux-2.image_id
  instance_type     = "t3.micro"
  user_data         = base64encode(local.user_data_private)
  ebs_optimized     = true
  enable_monitoring = true

  create_iam_instance_profile = true
  iam_role_name               = "complete-${local.name}"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Complete IAM role example"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # # Security group is set on the ENIs below
  security_groups = [var.private_sg_alb]

  target_group_arns = [var.target_group_arns_private]

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
      }
      }, {
      device_name = "/dev/sda1"
      no_device   = 1
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
      }
    }
  ]

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  cpu_options = {
    core_count       = 1
    threads_per_core = 1
  }

  credit_specification = {
    cpu_credits = "standard"
  }

  instance_market_options = {
    market_type = "spot"
  }

  maintenance_options = {
    auto_recovery = "default"
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 32
    instance_metadata_tags      = "enabled"
  }

  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = ["${var.private_sg_alb}"]
    }
  ]

  placement = {
    availability_zone = "${local.region}a"
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = merge({ WhatAmI = "Volume" })
    },
    {
      resource_type = "spot-instances-request"
      tags          = merge({ WhatAmI = "SpotInstanceRequest" })
    }
  ]

  # Autoscaling Schedule
  schedules = {
    night = {
      min_size         = 0
      max_size         = 0
      desired_capacity = 0
      recurrence       = "0 18 * * 1-5" # Mon-Fri in the evening
      time_zone        = "Europe/Rome"
    }

    morning = {
      min_size         = 0
      max_size         = 1
      desired_capacity = 1
      recurrence       = "0 7 * * 1-5" # Mon-Fri in the morning
    }

    go-offline-to-celebrate-new-year = {
      min_size         = 0
      max_size         = 0
      desired_capacity = 0
      start_time       = "2031-12-31T10:00:00Z" # Should be in the future
      end_time         = "2032-01-01T16:00:00Z"
    }
  }
  # Target scaling policy schedule based on average CPU load
  # scaling_policies = {
  #   avg-cpu-policy-greater-than-50 = {
  #     policy_type               = "TargetTrackingScaling"
  #     estimated_instance_warmup = 1200
  #     target_tracking_configuration = {
  #       predefined_metric_specification = {
  #         predefined_metric_type = "ASGAverageCPUUtilization"
  #       }
  #       target_value = 50.0
  #     }
  #   },
  # predictive-scaling = {
  #   policy_type = "PredictiveScaling"
  #   predictive_scaling_configuration = {
  #     mode                         = "ForecastAndScale"
  #     scheduling_buffer_time       = 10
  #     max_capacity_breach_behavior = "IncreaseMaxCapacity"
  #     max_capacity_buffer          = 10
  #     metric_specification = {
  #       target_value = 32
  #       predefined_scaling_metric_specification = {
  #         predefined_metric_type = "ASGAverageCPUUtilization"
  #         resource_label         = "testLabel"
  #       }
  #       predefined_load_metric_specification = {
  #         predefined_metric_type = "ASGTotalCPUUtilization"
  #         resource_label         = "testLabel"
  #       }
  #     }
  #   }
  # }
  # request-count-per-target = {
  #   policy_type               = "TargetTrackingScaling"
  #   estimated_instance_warmup = 120
  #   target_tracking_configuration = {
  #     predefined_metric_specification = {
  #       predefined_metric_type = "ALBRequestCountPerTarget"
  #       resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
  #     }
  #     target_value = 800
  #   }
  # }
}
# }




################################################################################
# Complete Database Autoscaling group
################################################################################

module "complete_database_asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  count  = var.enable_db_subnets ? 1 : 0
  # Autoscaling group
  name                            = "complete-${local.name}-db-v3"
  use_name_prefix                 = false
  instance_name                   = "${local.name}-instance-db-v3"
  ignore_desired_capacity_changes = false

  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  default_instance_warmup   = 300
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["${db_subnets[0]}", "${db_subnets[1]}", "${db_subnets[2]}"]

  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name        = "complete-${local.name}-db"
  launch_template_description = "Complete launch template example"
  update_default_version      = true

  image_id          = "ami-04cac1713d99a8a58"
  instance_type     = "t3.micro"
  user_data         = base64encode(local.user_data_db)
  ebs_optimized     = true
  enable_monitoring = true

  create_iam_instance_profile = true
  iam_role_name               = "complete-${local.name}"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Complete IAM role example"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # # Security group is set on the ENIs below
  security_groups = [var.db_sg_ist]

  # target_group_arns = [aws_alb_target_group.public_http.arn]

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = false
        encrypted             = true
        volume_size           = 20
        volume_type           = "gp2"
      }
      }, {
      device_name = "/dev/sda1"
      no_device   = 1
      ebs = {
        delete_on_termination = false
        encrypted             = true
        volume_size           = 30
        volume_type           = "gp2"
      }
    }
  ]

  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  cpu_options = {
    core_count       = 1
    threads_per_core = 1
  }

  credit_specification = {
    cpu_credits = "standard"
  }

  # enclave_options = {
  #   enabled = true # Cannot enable hibernation and nitro enclaves on same instance nor on T3 instance type
  # }

  # hibernation_options = {
  #   configured = true # Root volume must be encrypted & not spot to enable hibernation
  # }

  instance_market_options = {
    market_type = "spot"
  }

  # license_specifications = {
  #   license_configuration_arn = aws_licensemanager_license_configuration.test.arn
  # }

  maintenance_options = {
    auto_recovery = "default"
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 32
    instance_metadata_tags      = "enabled"
  }

  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = [var.db_sg_ist]
    }
  ]

  placement = {
    availability_zone = "${local.region}a"
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = merge({ WhatAmI = "Volume" })
    },
    {
      resource_type = "spot-instances-request"
      tags          = merge({ WhatAmI = "SpotInstanceRequest" })
    }
  ]

  tags = local.tags

  # Autoscaling Schedule
  schedules = {
    # night = {
    #   min_size         = 0
    #   max_size         = 0
    #   desired_capacity = 0
    #   recurrence       = "0 18 * * 1-5" # Mon-Fri in the evening
    #   time_zone        = "Europe/Rome"
    # }

    # morning = {
    #   min_size         = 0
    #   max_size         = 1
    #   desired_capacity = 1
    #   recurrence       = "0 7 * * 1-5" # Mon-Fri in the morning
    # }

    # go-offline-to-celebrate-new-year = {
    #   min_size         = 0
    #   max_size         = 0
    #   desired_capacity = 0
    #   start_time       = "2031-12-31T10:00:00Z" # Should be in the future
    #   end_time         = "2032-01-01T16:00:00Z"
    # }
  }
  # Target scaling policy schedule based on average CPU load
  scaling_policies = {
    avg-cpu-policy-greater-than-50 = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    },
    predictive-scaling = {
      policy_type = "PredictiveScaling"
      predictive_scaling_configuration = {
        mode                         = "ForecastAndScale"
        scheduling_buffer_time       = 10
        max_capacity_breach_behavior = "IncreaseMaxCapacity"
        max_capacity_buffer          = 10
        metric_specification = {
          target_value = 32
          predefined_scaling_metric_specification = {
            predefined_metric_type = "ASGAverageCPUUtilization"
            resource_label         = "testLabel"
          }
          predefined_load_metric_specification = {
            predefined_metric_type = "ASGTotalCPUUtilization"
            resource_label         = "testLabel"
          }
        }
      }
    }
  }
}


