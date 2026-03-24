terraform {
  backend "s3" {}
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = merge(
      {
        project = "heat-island-hackathon"
      },
      var.tags
    )
  }
}
