variable "civo_api_token" {
  sensitive = true
  description = "The Civo API token to use"
  type = string
}

variable "cloudflare_api_token" {
  sensitive = true
  description = "The Cloudflare API token to use"
  type = string
}

variable "ssh_enabled" {
  description = "Whether or not to open port 22 for SSH"
  type = bool
  default = false
}

variable "satisfactory_enabled" {
  description = "Whether or not to open ports for Satisfactory"
  type = bool
  default = false
}
