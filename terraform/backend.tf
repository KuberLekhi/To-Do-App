# Fill in <STATE_BUCKET_NAME> with the `state_bucket_name` output from
# `terraform/bootstrap` after you've applied it once. Then run:
#   terraform init -migrate-state
# (only needed the first time, to move from local state to this backend)

terraform {
  backend "s3" {
    bucket         = "todo-devops-demo-tf-state-85d27d93"
    key            = "todo-devops-demo/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "todo-devops-demo-tf-lock"
    encrypt        = true
  }
}
