provider "civo" {
  token = var.civo_api_token
  region = "NYC1"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
