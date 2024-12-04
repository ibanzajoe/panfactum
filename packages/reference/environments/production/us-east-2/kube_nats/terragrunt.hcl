include "panfactum" {
  path   = find_in_parent_folders("panfactum.hcl")
  expose = true
}

terraform {
  source = include.panfactum.locals.pf_stack_source
}


inputs = {
  pull_through_cache_enabled = true
  vpa_enabled                = true
  burstable_nodes_enabled    = true
  namespace                  = "default"
}
