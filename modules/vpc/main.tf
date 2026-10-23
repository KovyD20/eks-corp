locals {
  public_subnets  = { for i, az in var.availability_zones : az => cidrsubnet(var.vpc_cidr, 8, i + 1) }
  private_subnets = { for i, az in var.availability_zones : az => cidrsubnet(var.vpc_cidr, 8, i + 11) }
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# ─────────────────────────────────────────
# INTERNET GATEWAY
# ─────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# ─────────────────────────────────────────
# PUBLIC SUBNETS
# ─────────────────────────────────────────
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${each.key}"

    # Mandatory tags for AWS Load Balancer Controller!
    "kubernetes.io/role/elb"                                       = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# ─────────────────────────────────────────
# PRIVATE SUBNETS
# ─────────────────────────────────────────
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${each.key}"

    # Mandatory tags for AWS Load Balancer Controller!
    "kubernetes.io/role/internal-elb"                              = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# ─────────────────────────────────────────
# ELASTIC IP
# ─────────────────────────────────────────
resource "aws_eip" "nat" {
  for_each = var.enable_nat_gateway ? local.public_subnets : {}
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────
# NAT GATEWAY
# ─────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  for_each = var.enable_nat_gateway ? local.public_subnets : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────
# ROUTE TABLE – PUBLIC
# ─────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────
# ROUTE TABLE – PRIVATE
# ─────────────────────────────────────────
resource "aws_route_table" "private" {
  for_each = local.private_subnets
  vpc_id   = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[each.key].id
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rt-private-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}