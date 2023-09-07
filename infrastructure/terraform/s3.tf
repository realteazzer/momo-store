terraform {
    backend "s3" {
        endpoint   = "storage.yandexcloud.net"
        bucket     = "pelmeni-terraform-state-teazzer"
        region     = "ru-central1"
        key        = "terraform.tfstate"
        #access_key = "my-access-key"      -  backend.tfvars
        #secret_key = "my-secret-key"      -  backend.tfvars
    
        skip_region_validation      = true
        skip_credentials_validation = true
   }
}
