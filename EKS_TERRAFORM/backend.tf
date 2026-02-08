terraform {
  backend "s3" {
    bucket = "devsecops-netflix-saabiq" 
    key    = "EKS/terraform.tfstate"
    region = "ap-south-1"
  }
}
