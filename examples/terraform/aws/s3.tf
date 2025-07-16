resource "random_id" "bucket_suffix" {
  byte_length = 16
}

resource "aws_s3_bucket" "tenzir_blobs" {
  bucket = "tenzir-blobs-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "tenzir_blobs" {
  bucket = aws_s3_bucket.tenzir_blobs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}