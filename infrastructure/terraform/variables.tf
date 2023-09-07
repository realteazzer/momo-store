variable "token" {
  description = "user token"
  sensitive = true
  nullable  = false
}

variable "cloud_id" {
  type        = string
  description = "virtual cloud id"
  default     = "b1gooa04ta8c485uugvg"
  nullable    = false
}

variable "folder_id" {
  type        = string
  description = "id of the folder in cloud"
  default     = "b1gls68e9ceuu8gvv88g"
  nullable    = false
}

variable "zone" {
  type        = string
  description = "geo zone id"
  default     = "ru-central1-a"
  nullable    = false
}
