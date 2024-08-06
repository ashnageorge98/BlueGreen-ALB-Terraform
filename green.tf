resource "aws_instance" "green" {
  count = var.enable_green_env ? var.green_instance_count : 0

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids = [module.app_security_group.security_group_id]
  user_data = templatefile("${path.module}/init-script.sh", {
    file_content = "version 1.1 - #${count.index}"
  })

  tags = {
    Name = "green-${count.index}"
  }
   lifecycle {
    create_before_destroy = true
    prevent_destroy       = var.stop_green_instances
  } 
}

resource "aws_lb_target_group" "green" {
  name     = "green-tg-${random_pet.app.id}-lb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    port     = 80
    protocol = "HTTP"
    timeout  = 5
    interval = 10
  }
}

resource "aws_lb_target_group_attachment" "green" {
  count            = length(aws_instance.green)
  target_group_arn = aws_lb_target_group.green.arn
  target_id        = aws_instance.green[count.index].id
  port             = 80
  depends_on = [aws_instance_state.green]
}

variable "stop_green_instances" {
  description = "Flag to stop green environment instances"
  type        = bool
  default     = false
}

resource "aws_instance_state" "green" {
  count        = var.enable_green_env ? var.green_instance_count : 0
  instance_id  = aws_instance.green[count.index].id
  instance_state = var.stop_green_instances ? "stopped" : "running"
}

