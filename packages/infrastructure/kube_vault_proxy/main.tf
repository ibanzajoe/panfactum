terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.27.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.0.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.39.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.25.0"
    }
  }
}

locals {
  oauth2_proxy_match = {
    id = random_id.oauth2_proxy.hex
  }
}

module "pull_through" {
  count  = var.pull_through_cache_enabled ? 1 : 0
  source = "../aws_ecr_pull_through_cache_addresses"
}

module "kube_labels" {
  source = "../kube_labels"

  # generate: common_vars_no_extra_tags.snippet.txt
  pf_stack_version = var.pf_stack_version
  pf_stack_commit  = var.pf_stack_commit
  environment      = var.environment
  region           = var.region
  pf_root_module   = var.pf_root_module
  pf_module        = var.pf_module
  is_local         = var.is_local
  # end-generate

  extra_tags = merge(var.extra_tags, local.oauth2_proxy_match)
}

module "constants" {
  source = "../constants"

  matching_labels = local.oauth2_proxy_match

  # generate: common_vars_no_extra_tags.snippet.txt
  pf_stack_version = var.pf_stack_version
  pf_stack_commit  = var.pf_stack_commit
  environment      = var.environment
  region           = var.region
  pf_root_module   = var.pf_root_module
  pf_module        = var.pf_module
  is_local         = var.is_local
  # end-generate

  extra_tags = merge(var.extra_tags, local.oauth2_proxy_match)
}

resource "random_id" "oauth2_proxy" {
  byte_length = 8
  prefix      = "oauth2-proxy-"
}

/***************************************
* Vault IdP Setup
***************************************/

resource "vault_identity_oidc_key" "oidc" {
  name               = var.upstream_service_name
  allowed_client_ids = ["*"]
  rotation_period    = 60 * 60 * 8
  verification_ttl   = 60 * 60 * 24
}

data "vault_identity_group" "rbac_groups" {
  for_each   = toset(["rbac-superusers", "rbac-admins", "rbac-readers"])
  group_name = each.key
}

resource "vault_identity_oidc_assignment" "oidc" {
  name      = var.upstream_service_name
  group_ids = [for group in data.vault_identity_group.rbac_groups : group.id]
}

resource "vault_identity_oidc_client" "oidc" {
  name = var.upstream_service_name
  key  = vault_identity_oidc_key.oidc.name
  redirect_uris = [
    "https://${var.domain}/oauth2/callback",
  ]
  assignments = [
    vault_identity_oidc_assignment.oidc.name
  ]
  id_token_ttl     = 60 * 60 * 8
  access_token_ttl = 60 * 60 * 8
}

resource "vault_identity_oidc_provider" "oidc" {
  name = var.upstream_service_name

  https_enabled = true
  issuer_host   = var.vault_domain
  allowed_client_ids = [
    vault_identity_oidc_client.oidc.client_id
  ]
  scopes_supported = [
    "profile"
  ]
}

/***************************************
* Proxy
***************************************/
resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = var.namespace
    labels    = module.kube_labels.kube_labels
  }
  data = {
    cookie-secret = random_password.cookie_secret.result
    client-id     = vault_identity_oidc_client.oidc.client_id
    client-secret = vault_identity_oidc_client.oidc.client_secret
  }
}

resource "helm_release" "oauth2_proxy" {
  namespace       = var.namespace
  name            = "oauth2-proxy"
  repository      = "https://oauth2-proxy.github.io/manifests"
  chart           = "oauth2-proxy"
  version         = var.oauth2_proxy_helm_version
  recreate_pods   = false
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true

  values = [
    yamlencode({
      config = {
        cookieName     = "${var.namespace}-oauth2-proxy"
        existingSecret = kubernetes_secret.oauth2_proxy.metadata[0].name
      }
      extraArgs = flatten(concat(
        [
          "--provider", "oidc",
          "--provider-display-name", "Vault",
          "--redirect-url", "https://${var.domain}/oauth2/callback",
          "--oidc-issuer-url", vault_identity_oidc_provider.oidc.issuer,
          "--cookie-secure", "true",
          "--cookie-domain", var.domain,
          "--scope", "openid profile",
          "--silence-ping-logging"
        ],
        [for domain in var.allowed_email_domains : ["--email-domain", domain]]
      ))

      image = {
        repository = "${var.pull_through_cache_enabled ? module.pull_through[0].quay_registry : "quay.io"}/oauth2-proxy/oauth2-proxy"
      }
      customLabels = module.kube_labels.kube_labels
      podLabels    = module.kube_labels.kube_labels
      replicaCount = 2
      strategy = {
        type          = "Recreate"
        rollingUpdate = null
      }
      tolerations               = module.constants.burstable_node_toleration_helm
      affinity                  = module.constants.pod_anti_affinity_instance_type_helm
      topologySpreadConstraints = module.constants.topology_spread_zone_preferred
      resources = {
        requests = {
          memory = "100Mi"
        }
        limits = {
          memory = "130Mi"
        }
      }
    })
  ]
  timeout = 60
}

resource "kubernetes_manifest" "vpa" {
  count = var.vpa_enabled ? 1 : 0
  manifest = {
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name      = "oauth2-proxy"
      namespace = var.namespace
      labels    = module.kube_labels.kube_labels
    }
    spec = {
      targetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = "oauth2-proxy"
      }
    }
  }
  depends_on = [helm_release.oauth2_proxy]
}

/***************************************
* Ingress
***************************************/

module "ingress" {
  source = "../kube_ingress"

  namespace = var.namespace
  name      = "oauth2-proxy"
  ingress_configs = [{
    domains      = [var.domain]
    service      = "oauth2-proxy"
    service_port = 80
    path_prefix  = "/oauth2"
  }]

  rate_limiting_enabled          = true
  cross_origin_isolation_enabled = true
  permissions_policy_enabled     = true
  csp_enabled                    = true
  csp_style_src                  = "'self' 'unsafe-inline'"

  # generate: pass_common_vars.snippet.txt
  pf_stack_version = var.pf_stack_version
  pf_stack_commit  = var.pf_stack_commit
  environment      = var.environment
  region           = var.region
  pf_root_module   = var.pf_root_module
  is_local         = var.is_local
  extra_tags       = var.extra_tags
  # end-generate

  depends_on = [
    helm_release.oauth2_proxy
  ]
}
