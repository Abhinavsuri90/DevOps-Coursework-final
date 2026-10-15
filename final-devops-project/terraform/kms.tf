# Envelope encryption for Kubernetes Secrets stored in etcd (trivy AWS-0039).
resource "aws_kms_key" "eks" {
  description             = "Encrypts Kubernetes Secrets of ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = { Name = "${var.cluster_name}-secrets" }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

# The control plane role may use this one key, and nothing else.
resource "aws_iam_role_policy" "cluster_kms" {
  name = "${var.cluster_name}-secrets-kms"
  role = aws_iam_role.cluster.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:ListGrants", "kms:DescribeKey"]
      Resource = aws_kms_key.eks.arn
    }]
  })
}
