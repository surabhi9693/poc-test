provider "aws" {
  region = "us-west-2"
}

resource "aws_ecs_cluster" "hello_world" {
  name = "hello-world-cluster"
}


variable "docker_image" {
  description = "The Docker image to deploy"
  type        = string
}

resource "aws_ecs_task_definition" "hello_world_task" {
  family                   = "hello-world-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "hello-world"
      image     = "767398115349.dkr.ecr.us-west-2.amazonaws.com/hello-world:v1.0.0"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "hello_world_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.hello_world.id
  task_definition = aws_ecs_task_definition.hello_world_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-010677c7ca50c7227"]
    security_groups = ["sg-0b80b497c45782089"]
  }
}

resource "aws_alb" "hello_world_alb" {
  name               = "hello-world-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-0b80b497c45782089"]
  subnets            = ["subnet-010677c7ca50c7227", "subnet-059433eb5160b72b1"]

  enable_deletion_protection = false
}

resource "aws_alb_target_group" "hello_world_tg" {
  name     = "hello-world-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = "vpc-00ee86013309f6fb4"
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.hello_world_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.hello_world_tg.arn
  }
}

resource "aws_alb_target_group_attachment" "hello_world" {
  target_group_arn = aws_alb_target_group.hello_world_tg.arn
  target_id        = aws_ecs_service.hello_world_service.id
  port             = 3000
}
