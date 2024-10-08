resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}

resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "medusa-backend"
      image = "linuxserver/medusa:1.0.21"
      portMappings = [{
        containerPort = 9000
        hostPort      = 9000
        protocol      = "tcp"
      }]
      environment = [
        {
          name  = "DATABASE_URL"
          value = aws_db_instance.medusa_db.endpoint
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "medusa_service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = 1

  network_configuration {
    subnets         = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.medusa_tg.arn
    container_name   = "medusa-backend"
    container_port   = 9000
  }
}

resource "aws_lb" "medusa_lb" {
  name               = "medusa-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  idle_timeout = 60
}

resource "aws_lb_target_group" "medusa_tg" {
  name     = "medusa-tg"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.medusa_vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.medusa_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.medusa_tg.arn
  }
}