variable "tenancy_ocid" {
  description = "OCID of the tenancy to which your account belongs. To know more about where to find your tenancy OCID, refer to this link - https://docs.oracle.com/en-us/iaas/Content/General/Concepts/identifiers.htm#tenancy_ocid."
  validation {
        condition = (
          length(var.tenancy_ocid) > 14 &&
          can(regex("^ocid1.tenancy.", var.tenancy_ocid ))
        )
        error_message = "The tenancy OCID must start with <ocid1.tenancy....> and must be valid. Please check the value provided."
      }
}
variable "compartment_id" {
  description = "The OCID of the compartment in which to create the resources. The compartment OCID looks something like this - ocid1.compartment.oc1..<unique_ID>"
  validation {
        condition = (
          length(var.compartment_id) > 16 &&
          can(regex("^ocid1.compartment.", var.compartment_id ))
        )
        error_message = "The compartment OCID must start with <oocid1.compartment.....> and must be valid. Please check the value provided."
      }
}
variable "region" {
  description = "The unique identifier of the region in which you want the resources to be created. To get a list of all the regions and their unique identifiers in the OCI commercial realm refer to this link - https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm#About"
  validation {
        condition = (
          length(var.region) > 2 &&
          can(regex("^[0-9A-Za-z-]+$", var.region))
        )
        error_message = "Please provide a valid region."
      }
}
variable "lb_size" {
  description = "A template that determines the total pre-provisioned bandwidth (ingress plus egress) of the external and internal load balancer. The supported values are - 100Mbps, 10Mbps, 10Mbps-Micro, 400Mbps, 8000Mbps"
  validation {
        condition = (
          contains(["100Mbps", "10Mbps", "10Mbps-Micro", "400Mbps", "8000Mbps"], var.lb_size)
        )
        error_message = "Please provide a valid size."
      }
}
variable "availability_domain" {
  description = "The availability domain to place instances. To get the specific names of your tenancy's availability domains, use the ListAvailabilityDomains (https://docs.oracle.com/en-us/iaas/api/#/en/identity/20160918/AvailabilityDomain/ListAvailabilityDomains) operation, which is available in the IAM API. Example - Tpeb:PHX-AD-1,Tpeb:PHX-AD-2. Please provide comma separated values"
}
variable "min_and_max_instance_count"{
    type = string
    description = "The minimum and maximum number of instances that you would want to retain in the instance pool. Please give the minimum and maximum instance count values as comma separated input. For ex, '1,5' - where 1 is the minimum instance count and 5 is the maximum instance count."

    validation{
      condition = (
          can(regex("^[0-9]+$", split(",", var.min_and_max_instance_count)[0])) &&
          can(regex("^[0-9]+$", split(",", var.min_and_max_instance_count)[1])) &&
          split(",", var.min_and_max_instance_count)[0] < split(",", var.min_and_max_instance_count)[1]
          )
      error_message = "Minimum instance count value must be lesser than maximum instance count value."
    }
}
variable "password" {
  description = "The password for the admin account to be used to SSH into the ASAv for configuration. The password must be in encrypted form, please use configuration guide for the instructions or see the following link https://docs.oracle.com/en/database/other-databases/essbase/19.3/essad/create-vault-and-secrets.html "
  validation {
        condition = (
          length(var.password) > 6
        )
        error_message = "Please enter a valid password of length > 6."
      }
}

variable "cryptographic_endpoint" {
  type = string
  description = "Cryptographic endpoint URL will be used for decrypting password. It can be found in the Vault."
}

variable "master_encryption_key_id" {
  type = string
  description = "The OCID of key with which the password was encrypted. It can be found in the Vault."
}

variable "autoscale_group_prefix" {
  description = "The prefix to be used to name all the resources that are created using the template. For example, if the resource prefix is given as 'autoscale', all the resources are named as follows - autoscale_resource1, autoscale_resource2 etc. Note : Please make sure not give a resource prefix that starts with 'oci_' as these are reserved for services within the cloud and will throw an error."
  validation {
        condition = (
          can(regex("^[a-z][a-z0-9_]*[a-z0-9]$", var.autoscale_group_prefix)) &&
          substr(var.autoscale_group_prefix,0,4) != "oci" &&
          substr(var.autoscale_group_prefix,0,4) != "orcl"
        )
        error_message = "Please provide a valid resource group prefix without any special characters except hyphen."
      }
}

locals{
  day_0 = <<EOT
!
interface management0/0
management-only
nameif management
security-level 100
ip address dhcp setroute
no shutdown

same-security-traffic permit inter-interface
same-security-traffic permit intra-interface

!Interface Config
interface G0/0
nameif inside
security-level 100
no shutdown

interface G0/1
nameif outside
security-level 0
no shutdown

crypto key generate rsa modulus 2048
ssh 0 0 management
ssh timeout 60
ssh version 2
username admin password AsAv_AuT0Scale privilege 15
enable password AsAv_AuT0Scale
username admin attributes
service-type admin
aaa authentication ssh console LOCAL

access-list allow-all extended permit ip any any
access-group allow-all global

dns domain-lookup management
dns server-group DefaultDNS
name-server 8.8.8.8
!
EOT

  min_instance_count = split(",", var.min_and_max_instance_count)[0]
  max_instance_count = split(",", var.min_and_max_instance_count)[1]
  availability_domains = tolist("${split(",", var.availability_domain)}")
  instance_pool_id = "${length(local.availability_domains) == 1 ? "${oci_core_instance_pool.test_instance_pool_1[0].id}" : "${length(local.availability_domains) == 2 ? "${oci_core_instance_pool.test_instance_pool_2[0].id}" : "${oci_core_instance_pool.test_instance_pool_3[0].id}"}"}"
}

variable "asav_config_file_url" {
  description = "The URL of the configuration file uploaded to the object storage to be used to configure the ASAv. Example - https://objectstorage.us-phoenix-1.oraclecloud.com/p/<.....>/oci-asav-configuration.txt"
  validation {
        condition = (
          can(regex("^[0-9A-Za-z-/.:_]+$", var.asav_config_file_url))
        )
        error_message = "Please provide a valid URL."
      }
}

variable "mgmt_subnet_ocid" {
  description = "OCID of the Management subnet that is to be used."
  validation {
        condition = (
          length(var.mgmt_subnet_ocid) > 13 &&
          can(regex("^ocid1.subnet.", var.mgmt_subnet_ocid ))
        )
        error_message = "The subnet OCID must start with <ocid1.subnet....> and must be valid. Please check the value provided."
      }
}

variable "inside_subnet_ocid" {
  description = "OCID of the Inside subnet that is to be used."
  validation {
        condition = (
          length(var.inside_subnet_ocid) > 13 &&
          can(regex("^ocid1.subnet.", var.inside_subnet_ocid ))
        )
        error_message = "The subnet OCID must start with <ocid1.subnet....> and must be valid. Please check the value provided."
      }
}

variable "outside_subnet_ocid" {
  description = "OCID of the Outside subnet that is to be used."
  validation {
        condition = (
          length(var.outside_subnet_ocid) > 13 &&
          can(regex("^ocid1.subnet.", var.outside_subnet_ocid ))
        )
        error_message = "The subnet OCID must start with <ocid1.subnet....> and must be valid. Please check the value provided."
      }

}
variable "mgmt_nsg_ocid" {
  # default = "ocid1.networksecuritygroup.oc1.phx.aaaaaaaa4larsbybwy7mlt56nq2l7nygdvcup4g7x2bbgitcpkxjtc7ad5xq"
  description = "OCID of the Management subnet network security group that is to be used."
  validation {
        condition = (
          length(var.mgmt_nsg_ocid) > 27 &&
          can(regex("^ocid1.networksecuritygroup.", var.mgmt_nsg_ocid ))
        )
        error_message = "The NSG OCID must start with <ocid1.networksecuritygroup.....> and must be valid. Please check the value provided."
      }
}
variable "inside_nsg_ocid" {
  # default = "ocid1.networksecuritygroup.oc1.phx.aaaaaaaasb6hpq5vng2i6awnhz5ifqkzggw2ai2jsxdsoqoxyoviq3gvy3yq"
  description = "OCID of the Inside subnet network security group that is to be used."
  validation {
        condition = (
          length(var.inside_nsg_ocid) > 27 &&
          can(regex("^ocid1.networksecuritygroup.", var.inside_nsg_ocid ))
        )
        error_message = "The NSG OCID must start with <ocid1.networksecuritygroup.....> and must be valid. Please check the value provided."
      }
}
variable "outside_nsg_ocid" {
  description = "OCID of the Outside subnet network security group that is to be used."
  validation {
        condition = (
          length(var.outside_nsg_ocid) > 27 &&
          can(regex("^ocid1.networksecuritygroup.", var.outside_nsg_ocid ))
        )
        error_message = "The NSG OCID must start with <ocid1.networksecuritygroup.....> and must be valid. Please check the value provided."
      }
}
variable "elb_listener_port" {
  description = "List of comma separated communication ports for the external load balancer listener. Example - 80,8000."
}
variable "ilb_listener_port" {
  description = "List of comma separated communication ports for the internal load balancer listener. Example - 80,8000."
}
variable "health_check_port" {
  description = "The backend server port of external load balancer against which to run the health check."
  validation {
        condition = (
          can(regex("^[0-9]+$", var.health_check_port)) &&
          var.health_check_port > 0 &&
          var.health_check_port < 65535
        )
        error_message = "Please provide a valid port number between 1 and 65535."
      }
}
variable "instance_shape" {
  description = "The shape of the instance to be created. The shape determines the number of CPUs, amount of memory, and other resources allocated to the instance. Supported shapes for ASAv are - 'VM.Standard2.4' and 'VM.Standard2.8'."
  validation {
        condition = (
          contains(["VM.Standard2.4", "VM.Standard2.8"], var.instance_shape)
        )
        error_message = "Please provide a valid instance shape."
      }
}
variable "lb_bs_policy" {
  description = "The load balancer policy to be used for the internal and external load balancer backend set. To know more about how load balancer policies work, refer to this link - https://docs.oracle.com/en-us/iaas/Content/Balance/Reference/lbpolicies.htm . Supported values are - 'ROUND_ROBIN', 'LEAST_CONNECTIONS', 'IP_HASH'."
  validation {
        condition = (
          contains(["ROUND_ROBIN", "LEAST_CONNECTIONS", "IP_HASH"], var.lb_bs_policy)
        )
        error_message = "Please provide a valid policy."
      }
}
variable "image_name" {
  default = "Cisco ASA virtual firewall (ASAv)"
  description = "The name of the marketplace image to be used for creating the instance configuration."
}

variable "image_version" {
  type = string
  default = "9.16.1.28"
  description = "The Version of the ASAv image available in OCI Marketplace to be used. Currently following versions are available (i) 9.15.1.15    (ii) 9.16.1.28"
  validation {
        condition = (
          contains(["9.16.1.28", "9.15.1.15", ""], var.image_version)
        )
        error_message = "Please provide a available image version."
      }
}

variable "custom_image_ocid" {
  default = ""
  description = "OCID of the custom image to be used to create instance configuration if the marketplace image is not to be used."
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  region           = var.region
}

###########   Listing ID     ################
data "oci_marketplace_listings" "test_listings" {
  count = var.custom_image_ocid == "" ? 1 : 0
  name = [var.image_name]
}

data "oci_marketplace_listing" "test_listing" {
  count = var.custom_image_ocid == "" ? 1 : 0
  listing_id = data.oci_marketplace_listings.test_listings[count.index].listings[0].id
}

#################   Image ID    ################################
data "oci_marketplace_listing_package" "test_listing_package" {
  count = var.custom_image_ocid == "" ? 1 : 0
  listing_id      = data.oci_marketplace_listing.test_listing[count.index].id
  package_version = var.image_version
}

data "oci_core_app_catalog_listing_resource_version" "test_catalog_listing" {
  count = var.custom_image_ocid == "" ? 1 : 0
  listing_id       = data.oci_marketplace_listing_package.test_listing_package[count.index].app_catalog_listing_id
  resource_version = data.oci_marketplace_listing_package.test_listing_package[count.index].app_catalog_listing_resource_version
}

#################  marketplace agreements  ####################
resource "oci_marketplace_accepted_agreement" "test_accepted_agreement" {
  count = var.custom_image_ocid == "" ? 1 : 0
  agreement_id    = oci_marketplace_listing_package_agreement.test_listing_package_agreement[count.index].agreement_id
  compartment_id  = var.compartment_id
  listing_id      = data.oci_marketplace_listing.test_listing[count.index].id
  package_version = var.image_version
  signature       = oci_marketplace_listing_package_agreement.test_listing_package_agreement[count.index].signature
}

resource "oci_marketplace_listing_package_agreement" "test_listing_package_agreement" {
  count = var.custom_image_ocid == "" ? 1 : 0
  agreement_id    = data.oci_marketplace_listing_package_agreements.test_listing_package_agreements[count.index].agreements[0].id
  listing_id      = data.oci_marketplace_listing.test_listing[count.index].id
  package_version = var.image_version
}

data "oci_marketplace_listing_package_agreements" "test_listing_package_agreements" {
  count = var.custom_image_ocid == "" ? 1 : 0
  listing_id      = data.oci_marketplace_listing.test_listing[count.index].id
  package_version = var.image_version
}

resource "oci_load_balancer_load_balancer" "test_load_balancer_elb" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_external_load_balancer"
    shape = var.lb_size
    subnet_ids = [var.outside_subnet_ocid]

    #Optional
    ip_mode = "IPV4"
    is_private = "false"

}
resource "oci_load_balancer_load_balancer" "test_load_balancer_ilb" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_internal_load_balancer"
    shape = var.lb_size
    subnet_ids = [var.inside_subnet_ocid]

    #Optional
    ip_mode = "IPV4"
    is_private = "true"
}
resource "oci_load_balancer_backend_set" "test_backend_set_elb" {
    #Required
    health_checker {
        #Required
        protocol = "TCP"
        port = var.health_check_port
    }
    load_balancer_id = oci_load_balancer_load_balancer.test_load_balancer_elb.id
    name = "${var.autoscale_group_prefix}_elb_bs"
    policy = "${var.lb_bs_policy}"
}
resource "oci_load_balancer_backend_set" "test_backend_set_ilb" {
    #Required
    health_checker {
        #Required
        protocol = "TCP"
        port = var.health_check_port
    }
    load_balancer_id = oci_load_balancer_load_balancer.test_load_balancer_ilb.id
    name = "${var.autoscale_group_prefix}_ilb_bs"
    policy = "${var.lb_bs_policy}"
}
resource "oci_load_balancer_listener" "test_listener_elb" {
    #Required
    default_backend_set_name = oci_load_balancer_backend_set.test_backend_set_elb.name
    load_balancer_id = oci_load_balancer_load_balancer.test_load_balancer_elb.id
    name = "${var.autoscale_group_prefix}_elb_listener_${each.value}"
    port = each.value
    protocol = "TCP"
    for_each = toset("${split(",", var.elb_listener_port)}")
}
resource "oci_load_balancer_listener" "test_listener_ilb" {
    #Required
    default_backend_set_name = oci_load_balancer_backend_set.test_backend_set_ilb.name
    load_balancer_id = oci_load_balancer_load_balancer.test_load_balancer_ilb.id
    name = "${var.autoscale_group_prefix}_ilb_listener_${each.value}"
    port = each.value
    protocol = "TCP"
    for_each = toset("${split(",", var.ilb_listener_port)}")
}
resource "oci_core_instance_configuration" "test_instance_configuration" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_instance_configuration"
    instance_details {
        #Required
        instance_type = "compute"
        launch_details {
            #availability_domain = var.availability_domain
            compartment_id = var.compartment_id
            create_vnic_details {
                assign_public_ip = "true"
                display_name = "management"
                nsg_ids = [var.mgmt_nsg_ocid]
                private_ip = "true"
                skip_source_dest_check = "true"
                subnet_id = var.mgmt_subnet_ocid
            }
            display_name = "${var.autoscale_group_prefix}_instance_configuration"
            launch_mode = "PARAVIRTUALIZED"
            metadata = {"user_data" : base64encode("${local.day_0}")}
            shape = "${var.instance_shape}"
            source_details {
                #Required
                source_type = "image"
                image_id = var.custom_image_ocid == ""? data.oci_core_app_catalog_listing_resource_version.test_catalog_listing[0].listing_resource_id : var.custom_image_ocid
            }
        }
    }
    source = "NONE"
}

resource "oci_core_instance_pool" "test_instance_pool_1" {
    count = "${length(local.availability_domains) == 1 ? 1 : 0}"
    compartment_id = var.compartment_id
    instance_configuration_id = oci_core_instance_configuration.test_instance_configuration.id
    placement_configurations {
        availability_domain = local.availability_domains[0]
        primary_subnet_id = var.mgmt_subnet_ocid
    }
    size ="0"

    display_name = "${var.autoscale_group_prefix}_instance_pool"
}

resource "oci_core_instance_pool" "test_instance_pool_2" {
    count = "${length(local.availability_domains) == 2 ? 1 : 0}"
    compartment_id = var.compartment_id
    instance_configuration_id = oci_core_instance_configuration.test_instance_configuration.id
    placement_configurations {
        availability_domain = local.availability_domains[0]
        primary_subnet_id = var.mgmt_subnet_ocid
    }
    placement_configurations {
        availability_domain = local.availability_domains[1]
        primary_subnet_id = var.mgmt_subnet_ocid
    }
    size ="0"
    display_name = "${var.autoscale_group_prefix}_instance_pool"
}

resource "oci_core_instance_pool" "test_instance_pool_3" {
    count = "${length(local.availability_domains) == 3 ? 1 : 0}"
    compartment_id = var.compartment_id
    instance_configuration_id = oci_core_instance_configuration.test_instance_configuration.id
    placement_configurations {
        availability_domain = local.availability_domains[0]
        primary_subnet_id = var.mgmt_subnet_ocid
    }
    placement_configurations {
        availability_domain = local.availability_domains[1]
        primary_subnet_id = var.mgmt_subnet_ocid
    }
    placement_configurations {
        availability_domain = local.availability_domains[2]
        primary_subnet_id = var.mgmt_subnet_ocid
    }
    size ="0"
    display_name = "${var.autoscale_group_prefix}_instance_pool"
}

resource "oci_functions_application" "test_application" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_application"
    subnet_ids = [var.mgmt_subnet_ocid]

    #Optional
    config = {
    "elb_id": "${oci_load_balancer_load_balancer.test_load_balancer_elb.id}",
    "elb_backend_set_name": "${oci_load_balancer_backend_set.test_backend_set_elb.name}",
    "elb_listener_port_no": "${var.elb_listener_port}",
    "compartment_id": "${var.compartment_id}",
    "ilb_id": "${oci_load_balancer_load_balancer.test_load_balancer_ilb.id}",
    "ilb_listener_port_no": "${var.ilb_listener_port}",
    "ilb_backend_set_name": "${oci_load_balancer_backend_set.test_backend_set_ilb.name}",
    "inside_interface_name": "inside",
    "outside_interface_name": "outside",
    "instance_pool_id": local.instance_pool_id,
    "region": "${var.region}",
    "metric_namespace_name": "${var.autoscale_group_prefix}_metric_namespace",
    "resource_group_name": "${var.autoscale_group_prefix}_resource_group",
    "cpu_metric_name": "${var.autoscale_group_prefix}_cpu_usage",
    "healthcheck_metric_name": "${var.autoscale_group_prefix}_health_check",
    "encrypted_password": "${var.password}",
    "cryptographic_endpoint": "${var.cryptographic_endpoint}",
    "master_key_id": "${var.master_encryption_key_id}",
    "min_instance_count": "${local.min_instance_count}",
    "max_instance_count": "${local.max_instance_count}",
    "inside_subnet_id": "${var.inside_subnet_ocid }",
    "inside_nsg_id": "${var.inside_nsg_ocid}",
    "outside_subnet_id": "${var.outside_subnet_ocid}",
    "outside_nsg_id": "${var.outside_nsg_ocid}",
    "configuration_file_url": "${var.asav_config_file_url}"
}
}


resource "oci_artifacts_container_repository" "post_launch_actions_container_repository" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_post_launch_actions/post_launch_actions"
}

resource "oci_artifacts_container_repository" "publish_metrics_container_repository" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_publish_metrics/publish_metrics"
}

resource "oci_artifacts_container_repository" "remove_unhealthy_backend_container_repository" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_remove_unhealthy_backend/remove_unhealthy_backend"
}

resource "oci_artifacts_container_repository" "scale_in_container_repository" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_scale_in/scale_in"
}

resource "oci_artifacts_container_repository" "scale_out_container_repository" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_scale_out/scale_out"
}
