variable "aws_region" {
  description = "AWS region"     # 変数の説明
  type        = string           # データ型（文字列）
  default     = "ap-northeast-1" # デフォルト値（東京リージョン）
}

variable "ami_id" {
  description = "AMI ID for EC2"
  type        = string
  default     = "ami-0d52744d6551d851e" # Amazon Linux 2023（東京リージョン用）
}
