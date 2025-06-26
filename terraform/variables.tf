#----------vpc
variable "aws_region" {
    default = "us-east-2"
}

variable "vpc_cidr" {
    default = "10.0.0.0/16"
}

variable "public_subnet_1" {
    default = "10.0.1.0/24"
}

variable "public_subnet_2" {
    default = "10.0.2.0/24"
}

# --- image tag


#--ecs
variable "strapi_cluster" {
  default = "strapi-cluster"
}
variable "strapi_service" {
  default = "strapi-service"
}