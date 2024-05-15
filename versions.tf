terraform {
  required_providers {
    civo = {
      source = "civo/civo"
      version = "1.0.41"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}
