#################################################################
## DO NOT EDIT - This file is automatically generated.
#################################################################

# This fixes an issue if the Authentik provider is enabled
# but the sourced module does not set up the authentik provider
# correctly.
terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "${authentik_version}"
    }
  }
}