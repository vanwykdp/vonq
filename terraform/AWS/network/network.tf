resource "aws_vpc" "vonq" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vonq.id
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-primary-igw"
  })
}

resource "aws_subnet" "public" {
  count             = 2  # One per AZ
  vpc_id            = aws_vpc.vonq.id
  cidr_block        = cidrsubnet(aws_vpc.vonq.cidr_block, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index}"
  })
}

resource "aws_subnet" "proxy" {
  count             = 2
  vpc_id            = aws_vpc.vonq.id
  cidr_block        = cidrsubnet(aws_vpc.vonq.cidr_block, 4, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-proxy-subnet-${count.index}"
  })
}

resource "aws_subnet" "app_backend" {
  count             = 2
  vpc_id            = aws_vpc.vonq.id
  cidr_block        = cidrsubnet(aws_vpc.vonq.cidr_block, 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-app-backend-subnet-${count.index}"
  })
}

resource "aws_subnet" "data_layer" {
  count             = 2
  vpc_id            = aws_vpc.vonq.id
  cidr_block        = cidrsubnet(aws_vpc.vonq.cidr_block, 4, count.index + 6)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-data-layer-subnet-${count.index}"
  })
}

resource "aws_nat_gateway" "natgw" {
  count         = 2
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-nat-gateway-${count.index}"
  })
}

resource "aws_eip" "nat_eip" {
  count = 2
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vonq.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.default_tags, {
    Name = "public-rt"
  })
}

resource "aws_route_table_association" "public_association" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.vonq.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw[count.index].id
  }
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "proxy_assoc" {
  count          = 2
  subnet_id      = aws_subnet.proxy[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "app_assoc" {
  count          = 2
  subnet_id      = aws_subnet.app_backend[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "data_assoc" {
  count          = 2
  subnet_id      = aws_subnet.data_layer[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

data "aws_availability_zones" "available" {}
