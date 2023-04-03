resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = var.dynamo_db_state
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}