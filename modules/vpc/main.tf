data "aws_availability_zones" "available" {}

################################################################################
# vpc
################################################################################

locals {
  cidr     = "${var.cidr-start}.0.0/16"
  vpc-name = "${var.project-name}-${var.tier}-vpc"
}

resource "aws_vpc" "main" {
  cidr_block           = local.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.vpc-name
  }
}

################################################################################
# public subnet
################################################################################

locals {
  azs = data.aws_availability_zones.available.names
  public-subnets = [
    "${var.cidr-start}.0.0/22",
    "${var.cidr-start}.4.0/22",
    "${var.cidr-start}.8.0/22"
  ]
}

resource "aws_internet_gateway" "igw" {
  count = length(local.public-subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${local.vpc-name}-igw"
  }
}

resource "aws_route_table" "public" {
  count = length(local.public-subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${local.vpc-name}-public"
  }
}

resource "aws_route" "public-igw" {
  count = length(local.public-subnets) > 0 ? 1 : 0

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
  route_table_id         = aws_route_table.public[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_subnet" "public" {
  count = length(local.public-subnets)

  availability_zone       = local.azs[count.index]
  cidr_block              = local.public-subnets[count.index]
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    "Name"                                                      = "${local.vpc-name}-public-${local.azs[count.index]}"
    "kubernetes.io/cluster/${var.project-name}-${var.tier}-eks" = "shared"
    "kubernetes.io/role/elb"                                    = "1"
  }
}

resource "aws_route_table_association" "public" {
  count = length(local.public-subnets)

  route_table_id = aws_route_table.public[0].id
  subnet_id      = aws_subnet.public[count.index].id
}

################################################################################
# private subnet
################################################################################

locals {
  private-subnets = [
    "${var.cidr-start}.100.0/22",
    "${var.cidr-start}.104.0/22",
    "${var.cidr-start}.108.0/22"
  ]
}

resource "aws_route_table" "private" {
  count = length(local.azs)

  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${local.vpc-name}-private-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count = length(local.private-subnets)

  availability_zone = local.azs[count.index]
  cidr_block        = local.private-subnets[count.index]
  vpc_id            = aws_vpc.main.id

  tags = {
    "Name"                                                      = "${local.vpc-name}-private-${local.azs[count.index]}"
    "kubernetes.io/cluster/${var.project-name}-${var.tier}-eks" = "shared"
    "kubernetes.io/role/internal-elb"                           = "1"
  }
}

resource "aws_route_table_association" "private" {
  count = length(local.private-subnets)

  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

################################################################################
# database subnet
################################################################################

locals {
  database-subnets = [
    "${var.cidr-start}.200.0/22",
    "${var.cidr-start}.204.0/22",
    "${var.cidr-start}.208.0/22"
  ]
}

resource "aws_subnet" "database" {
  count = length(local.database-subnets)

  availability_zone = local.azs[count.index]
  cidr_block        = local.database-subnets[count.index]
  vpc_id            = aws_vpc.main.id

  tags = {
    "Name" = "${local.vpc-name}-db-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "database" {
  count = length(local.database-subnets)

  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.database[count.index].id
}

resource "aws_db_subnet_group" "database" {
  count = length(local.database-subnets) > 0 ? 1 : 0

  name        = "${local.vpc-name}-db-subnet-group"
  description = "Database subnet group for ${local.vpc-name}"
  subnet_ids  = aws_subnet.database[*].id

  tags = {
    "Name" = "${local.vpc-name}-db-subnet-group"
  }
}

################################################################################
# nat subnet
################################################################################

resource "aws_eip" "nat" {
  count = length(local.azs)

  vpc = true

  tags = {
    "Name" = "${local.vpc-name}-eip-${local.azs[count.index]}"
  }
}

resource "aws_nat_gateway" "nat" {
  count = length(local.azs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    "Name" = "${local.vpc-name}-nat-${local.azs[count.index]}"
  }
}

resource "aws_route" "private-nat" {
  count = length(local.azs)

  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
  route_table_id         = aws_route_table.private[count.index].id

  timeouts {
    create = "5m"
  }
}
