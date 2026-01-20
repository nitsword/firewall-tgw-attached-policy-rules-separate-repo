output "bucket_name" {
  value = var.existing_s3_bucket_name == "" ? aws_s3_bucket.this[0].bucket : var.existing_s3_bucket_name
}

output "bucket_id" {
  value = var.existing_s3_bucket_name == "" ? aws_s3_bucket.this[0].id : var.existing_s3_bucket_name
}

output "bucket_arn" {
  # If existing bucket name is provided, we might not have the ARN, 
  value = var.existing_s3_bucket_name == "" ? aws_s3_bucket.this[0].arn : "arn:aws:s3:::${var.existing_s3_bucket_name}"
}