provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1" 
}

resource "aws_ecr_repository" "rearc_repo" {
  name = "rearc-repo" 
}

resource "aws_ecs_cluster" "holmes_cluster" {
  name = "holmes_cluster" 
}

resource "aws_ecs_task_definition" "my_first_task" {
  family                   = "my-first-task" 
  container_definitions    = <<DEFINITION
  [
    {
      "name": "my-first-task",
      "image": "${aws_ecr_repository.rearc_repo.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] 
  network_mode             = "awsvpc" 
  memory                   = 512 
  cpu                      = 256   
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Reference VPC
resource "aws_default_vpc" "quest-vpc" {
}

# Reference to subnets
resource "aws_default_subnet" "pubsub" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "mysub2" {
  availability_zone = "us-east-1b"
}

## FARGATE SERVICE

resource "aws_ecs_service" "holmes_service" {
  name            = "holmes-service"
  cluster         = "${aws_ecs_cluster.holmes_cluster.id}"
  task_definition = "${aws_ecs_task_definition.my_first_task.arn}"
  launch_type     = "FARGATE"
  desired_count   = 2 

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" 
    container_name   = "${aws_ecs_task_definition.my_first_task.family}"
    container_port   = 3000 
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.pubsub.id}", "${aws_default_subnet.mysub2.id}"]
    assign_public_ip = true 
    security_groups  = ["${aws_security_group.holmes_sg.id}"] 
  }
}

## LOAD BALANCER CODE

resource "aws_alb" "application_load_balancer" {
  name               = "holmes-quest-lb" 
  load_balancer_type = "application"
  subnets = [ 
    "${aws_default_subnet.pubsub.id}",
    "${aws_default_subnet.mysub2.id}"
  ]
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80 
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

## Target Group and Listener code for LB

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.quest-vpc.id}" 
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" 
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" 
  }
}

## SECURITY GROUP

resource "aws_security_group" "holmes_sg" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }
}


## TLS SELF SIGNED

resource "tls_private_key" "sample_key" {
  algorithm = "ECDSA"
}

resource "tls_self_signed_cert" "rearc_ss_cert" {
  key_algorithm   = "${tls_private_key.sample_key.algorithm}"
  private_key_pem = "${tls_private_key.sample_key.private_key_pem}"

  validity_period_hours = 12
  early_renewal_hours = 3


  allowed_uses = [
      "key_encipherment",
      "digital_signature",
      "server_auth",
  ]

  dns_names = ["rearc.com", "rearc.net"]

  subject {
      common_name  = "rearc.com"
      organization = "Rearc"
  }
}

resource "aws_iam_server_certificate" "rearc_cert" {
  name             = "example_self_signed_cert"
  certificate_body = "${tls_self_signed_cert.rearc_ss_cert.cert_pem}"
  private_key      = "${tls_private_key.rearc_ss_cert.private_key_pem}"
}