variable "aws_region_name" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-3"
}

variable "aws_az_name" {
  description = "Availability Zone for deployment"
  type        = string
  default     = "eu-west-3a"
}

variable "ami_image" {
  description = "AMI ID for EC2 instances (Amazon Linux 2023 kernel-6.1 in eu-west-3 with EC2 Instance Connect built-in)"
  type        = string
  default     = "ami-0f00e1cf9df80b6ac"
}

variable "instance_type" {
  description = "EC2 instance type (Free Tier eligible: t2.micro or t3.micro depending on region)"
  type        = string
  default     = "t2.micro"
}

variable "web_instance_count" {
  description = "Number of WordPress web instances (1 for low-cost demo, 2 for HA)"
  type        = number
  default     = 1
}
