data "harvester_clusternetwork" "mgmt" {
  name = "mgmt"
}
# resource "harvester_clusternetwork" "data" {
#   name = "dataplane"
# }
# resource "harvester_vlanconfig" "dataplane" {
#   name = "cluster-vlan-dataplane"

#   cluster_network_name = harvester_clusternetwork.data.name

#   uplink {
#     nics = [
#       "eno1",
#       "eno2"
#     ]

#     bond_mode = "active-backup"
#     mtu       = 1500
#   }
# }
resource "harvester_network" "services" {
  name      = "services"
  namespace = "default"

  vlan_id = 5
  cluster_network_name = data.harvester_clusternetwork.mgmt.name
}
resource "harvester_network" "sandbox" {
  name      = "sandbox"
  namespace = "default"

  vlan_id = 6
  cluster_network_name = data.harvester_clusternetwork.mgmt.name
}
resource "harvester_network" "dev" {
  name      = "dev"
  namespace = "default"

  vlan_id = 7
  cluster_network_name = data.harvester_clusternetwork.mgmt.name
}
resource "harvester_network" "prod" {
  name      = "prod"
  namespace = "default"

  vlan_id = 8
  cluster_network_name = data.harvester_clusternetwork.mgmt.name
}