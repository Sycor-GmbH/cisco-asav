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
  # default = "ocid1.compartment.oc1..aaaaaaaaa6yubbqnwm32i3th564zm3ndenui7xv4rkcx4urcxb5pypoj52eq"
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
variable "autoscale_group_prefix" {
  description = "The prefix to be used to name all the resources that are created using the template. For example, if the resource prefix is given as 'autoscale', all the resources are named as follows - autoscale_resource1, autoscale_resource2 etc. Note : Please make sure not give a resource prefic that starts with 'oci_' as these are reserved for services within the cloud and will throw an error."
  validation {
        condition = (
          can(regex("^[a-z][a-z0-9_]*[a-z0-9]$", var.autoscale_group_prefix)) &&
          substr(var.autoscale_group_prefix,0,4) != "oci" &&
          substr(var.autoscale_group_prefix,0,4) != "orcl"
        )
        error_message = "Please provide a valid resource group prefix without any special characters except underscore."
      }
}
variable "scaling_thresholds"{
    type = string
    description = "The CPU usage thresholds to be used for scale-in and scaleout. Please give the scale-in and scale-out threshold values as comma separated input. For ex, '15,50' - where 15 is the scale-in threshold and 50 is the scale-out threshold."

    validation{
      condition = (
          can(regex("^[0-9]+$", split(",", var.scaling_thresholds)[0])) &&
          can(regex("^[0-9]+$", split(",", var.scaling_thresholds)[1])) &&
          split(",", var.scaling_thresholds)[0] < split(",", var.scaling_thresholds)[1]
          )
      error_message = "Scale in threshold value must be lesser than scale out threshold value."
    }
}
locals {
    scaleIn_threshold = split(",", var.scaling_thresholds)[0]
    scaleOut_threshold = split(",", var.scaling_thresholds)[1]
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  region           = var.region
}

data "oci_functions_applications" "test_applications" {
    #Required
    compartment_id = var.compartment_id

    #Optional
    display_name = "${var.autoscale_group_prefix}_application"
}

data "oci_functions_functions" "test_functions_post_launch" {
    #Required
    application_id = data.oci_functions_applications.test_applications.applications[0].id

    #Optional
    display_name = "post_launch_actions"
}
data "oci_functions_functions" "test_functions_scale_in" {
    #Required
    application_id = data.oci_functions_applications.test_applications.applications[0].id

    #Optional
    display_name = "scale_in"
}
data "oci_functions_functions" "test_functions_scale_out" {
    #Required
    application_id = data.oci_functions_applications.test_applications.applications[0].id

    #Optional
    display_name = "scale_out"
}
data "oci_functions_functions" "test_functions_post_metrics" {
    #Required
    application_id = data.oci_functions_applications.test_applications.applications[0].id

    #Optional
    display_name = "publish_metrics"
}

data "oci_functions_functions" "test_functions_remove_unhealthy_vms" {
    #Required
    application_id = data.oci_functions_applications.test_applications.applications[0].id

    #Optional
    display_name = "remove_unhealthy_backend"
}

resource "oci_logging_log_group" "test_log_group" {
    #Required
    compartment_id = var.compartment_id
    display_name = "${var.autoscale_group_prefix}_log_group"

    #Optional
    description = "Application log group"
}

resource "oci_logging_log" "test_log" {
    #Required
    display_name = "${var.autoscale_group_prefix}_log"
    log_group_id = oci_logging_log_group.test_log_group.id
    log_type = "SERVICE"

    #Optional
    configuration {
        #Required
        source {
            #Required
            category = "invoke"
            resource = data.oci_functions_applications.test_applications.applications[0].id
            service = "functions"
            source_type = "OCISERVICE"
        }

        #Optional
        compartment_id = var.compartment_id
    }
    is_enabled = "true"
    retention_duration = "30"
}


# scale-in, scale-out, post-metrics,
resource "oci_events_rule" "test_rule" {
    #Required
    actions {
        #Required
        actions {
            #Required
            action_type = "FAAS"
            is_enabled = "true"

            #Optional
            description = "Triggers attachment of vNICs and configures ASAv after instance creation."
            function_id = data.oci_functions_functions.test_functions_post_launch.functions[0].id
        }

        actions {
            action_type = "FAAS"
            is_enabled = "true"

            description = "Triggers the function to post the cpu metrics."
            function_id = data.oci_functions_functions.test_functions_post_metrics.functions[0].id
        }
    }
    compartment_id = var.compartment_id
    condition = "{ \"eventType\" : [\"com.oraclecloud.computeapi.launchinstance.end\"]}"
    display_name = "${var.autoscale_group_prefix}_event"
    is_enabled = "true"

}

resource "oci_ons_notification_topic" "test_notification_topic_scale_in" {
    #Required
    compartment_id = var.compartment_id
    name = "${var.autoscale_group_prefix}_scale_in"

}
resource "oci_ons_notification_topic" "test_notification_topic_scale_out" {
    #Required
    compartment_id = var.compartment_id
    name = "${var.autoscale_group_prefix}_scale_out"

}

resource "oci_ons_notification_topic" "test_notification_topic_post_metrics" {
    #Required
    compartment_id = var.compartment_id
    name = "${var.autoscale_group_prefix}_post_metrics"

}

resource "oci_ons_notification_topic" "test_notification_topic_remove_unhealthy_vms" {
    #Required
    compartment_id = var.compartment_id
    name = "${var.autoscale_group_prefix}_remove_unhealthy_vms"

}

resource "oci_ons_subscription" "test_subscription_scale_in" {
    #Required
    compartment_id = var.compartment_id
    endpoint = data.oci_functions_functions.test_functions_scale_in.functions[0].id
    protocol = "ORACLE_FUNCTIONS"
    topic_id = oci_ons_notification_topic.test_notification_topic_scale_in.id
}

resource "oci_ons_subscription" "test_subscription_scale_out" {
    #Required
    compartment_id = var.compartment_id
    endpoint = data.oci_functions_functions.test_functions_scale_out.functions[0].id
    protocol = "ORACLE_FUNCTIONS"
    topic_id = oci_ons_notification_topic.test_notification_topic_scale_out.id
}

resource "oci_ons_subscription" "test_subscription_post_metrics" {
    #Required
    compartment_id = var.compartment_id
    endpoint = data.oci_functions_functions.test_functions_post_metrics.functions[0].id
    protocol = "ORACLE_FUNCTIONS"
    topic_id = oci_ons_notification_topic.test_notification_topic_post_metrics.id
}

resource "oci_ons_subscription" "test_subscription_remove_unhealthy_vms" {
    #Required
    compartment_id = var.compartment_id
    endpoint = data.oci_functions_functions.test_functions_remove_unhealthy_vms.functions[0].id
    protocol = "ORACLE_FUNCTIONS"
    topic_id = oci_ons_notification_topic.test_notification_topic_remove_unhealthy_vms.id
}

resource "oci_monitoring_alarm" "test_alarm_new_scale_in" {
    #Required
    compartment_id = var.compartment_id
    destinations = [oci_ons_notification_topic.test_notification_topic_scale_in.id]
    display_name = "${var.autoscale_group_prefix}_scale_in"
    is_enabled = "true"
    metric_compartment_id = var.compartment_id
    namespace = "${var.autoscale_group_prefix}_metric_namespace"
    query = "${var.autoscale_group_prefix}_cpu_usage[2m]{resourceId= \"${var.compartment_id}\"}.max() <= ${local.scaleIn_threshold}"
    severity = "CRITICAL"

    #Optional
    # body = "Hi, ASAv Minimum threshold has reached. Scale-in Function has been invoked. Thanks, Cisco ASAv Team"
    repeat_notification_duration = "PT12M"
    # resolution = "1m"
    pending_duration = "PT2M"
    resource_group = "${var.autoscale_group_prefix}_resource_group"
}
resource "oci_monitoring_alarm" "test_alarm_new_scale_out" {
    #Required
    compartment_id = var.compartment_id
    destinations = [oci_ons_notification_topic.test_notification_topic_scale_out.id]
    display_name = "${var.autoscale_group_prefix}_scale_out"
    is_enabled = "true"
    metric_compartment_id = var.compartment_id
    namespace = "${var.autoscale_group_prefix}_metric_namespace"
    query = "${var.autoscale_group_prefix}_cpu_usage[2m]{resourceId = \"${var.compartment_id}\"}.max() > ${local.scaleOut_threshold}"
    severity = "CRITICAL"

    #Optional
    # body = "Hi, ASAv Maximum threshold has reached. Scale-Out Function has been invoked. Thanks, Cisco ASAv Team"
    repeat_notification_duration = "PT12M"
    # resolution = "1m"
    pending_duration = "PT2M"
    resource_group = "${var.autoscale_group_prefix}_resource_group"
}

resource "oci_monitoring_alarm" "test_alarm_new_post_metrics" {
    #Required
    compartment_id = var.compartment_id
    destinations = [oci_ons_notification_topic.test_notification_topic_post_metrics.id]
    display_name = "${var.autoscale_group_prefix}_post_metrics"
    is_enabled = "true"
    metric_compartment_id = var.compartment_id
    namespace = "${var.autoscale_group_prefix}_metric_namespace"
    query = "${var.autoscale_group_prefix}_cpu_usage[1m]{resourceId= \"${var.compartment_id}\"}.max() <= 100"
    severity = "CRITICAL"

    #Optional
    repeat_notification_duration = "PT2M"
    resolution = "1m"
    resource_group = "${var.autoscale_group_prefix}_resource_group"
}

resource "oci_monitoring_alarm" "test_alarm_new_health_check_status" {
    #Required
    compartment_id = var.compartment_id
    destinations = [oci_ons_notification_topic.test_notification_topic_remove_unhealthy_vms.id]
    display_name = "${var.autoscale_group_prefix}_health_check"
    is_enabled = "true"
    metric_compartment_id = var.compartment_id
    namespace = "${var.autoscale_group_prefix}_metric_namespace"
    query = "${var.autoscale_group_prefix}_health_check[1h]{resourceId=\"${var.compartment_id}\"}.max() > 0"
    severity = "CRITICAL"

    #Optional
    repeat_notification_duration = "PT60M"
    # resolution = "1m"
    pending_duration = "PT60M"
    resource_group = "${var.autoscale_group_prefix}_resource_group"
}
