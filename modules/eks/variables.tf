variable "project-name" {}

variable "tier" {}

variable "vpc-id" {}

variable "vpc-private-subnets" {
  type = list(string)
}
