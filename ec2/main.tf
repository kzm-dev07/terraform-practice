# Terraformのバージョンとプロバイダの指定
# プロバイダ：AWS、GCPなどのクラウドサービスと通信するためのプラグイン
terraform {
  required_version = "~> 1.15.2" # Terraform本体のバージョン指定
  required_providers {
    aws = {
      source  = "hashicorp/aws" # プロバイダの提供元
      version = "~> 6.44.0"     # プロバイダのバージョン（6.x系を使用）
    }
  }
  # Terraformの状態管理をS3バケットで行う設定 ※事前にS3バケットを作成しておく必要あり
  backend "s3" {
    bucket  = "terraform-practice-ec2"
    region  = "ap-northeast-1"
    key     = "terraform.tfstate" # 状態ファイルの保存場所（S3バケット内のパス）
    encrypt = true
  }
}

# AWSプロバイダの設定
provider "aws" {
  region = var.aws_region # variables.tfで定義した変数を参照
}

# VPC（Virtual Private Cloud）
# AWSアカウント内の仮想ネットワーク空間
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"              # IPアドレスの範囲（65,536個のIPアドレス）
  enable_dns_hostnames = true                       # DNSホスト名を有効化
  enable_dns_support   = true                       # DNS解決を有効化
  tags                 = { Name = "terraform-vpc" } # 管理用のタグ（名前）
}

# パブリックサブネット
# VPC内の一部領域で、インターネットからアクセス可能なネットワーク
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id      # 上で作成したVPCのIDを参照
  cidr_block              = "10.0.1.0/24"        # 256個のIPアドレス
  availability_zone       = "${var.aws_region}a" # アベイラビリティゾーン（物理的なデータセンター）
  map_public_ip_on_launch = true                 # インスタンス起動時に自動でパブリックIP割り当て
  tags                    = { Name = "terraform-public-subnet" }
}

# インターネットゲートウェイ
# VPCとインターネットを接続するゲート
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "terraform-igw" }
}

# ルートテーブル
# ネットワークトラフィックの経路を定義
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # すべての宛先（インターネット全体）
    gateway_id = aws_internet_gateway.main.id # インターネットゲートウェイ経由で通信
  }

  tags = { Name = "terraform-public-rt" }
}

# ルートテーブルとサブネットの関連付け
# サブネットにルートテーブルを適用
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# セキュリティグループ
# ファイアウォールのルール定義（どのポートからの通信を許可するか）
resource "aws_security_group" "web" {
  name        = "terraform-web-sg"
  description = "Security group for web server"
  vpc_id      = aws_vpc.main.id

  # インバウンドルール（外部からの通信）：HTTP
  ingress {
    from_port   = 80            # 開始ポート
    to_port     = 80            # 終了ポート
    protocol    = "tcp"         # プロトコル
    cidr_blocks = ["0.0.0.0/0"] # すべてのIPアドレスから許可
    description = "Allow HTTP"
  }

  # インバウンドルール：SSH（サーバーにリモート接続するため）
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 本番環境では自社IPのみに制限推奨
    description = "Allow SSH"
  }

  # アウトバウンドルール（サーバーから外部への通信）
  egress {
    from_port   = 0 # すべてのポート
    to_port     = 0
    protocol    = "-1"          # すべてのプロトコル
    cidr_blocks = ["0.0.0.0/0"] # すべての宛先へ許可
  }

  tags = { Name = "terraform-web-sg" }
}

# EC2インスタンス（仮想サーバー）
resource "aws_instance" "web" {
  ami                    = var.ami_id # Amazon Machine Image（OSのテンプレート）
  instance_type          = "t2.micro" # インスタンスタイプ（CPU・メモリのスペック）
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  tags                   = { Name = "terraform-web-server" }
}
