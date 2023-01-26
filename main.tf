# --------------------------------------------------------
# Provider
# --------------------------------------------------------
terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.46"
        }
        confluent = {
            source = "confluentinc/confluent"
            version = "1.23.0"
        }
    }
}

# --------------------------------------------------------
# Authenticate - Create Environment and Cluster
# --------------------------------------------------------

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key   # OR USE ENV VAR  CONFLUENT_CLOUD_API_KEY
  cloud_api_secret = var.confluent_cloud_api_secret # OR USE ENV VAR CONFLUENT_CLOUD_API_SECRET
}

 resource "confluent_environment" "environment" {
   display_name =  "Jude"
 }

 resource "confluent_kafka_cluster" "quickstart" {
   display_name = "quickstart_cluster"
   availability = "SINGLE_ZONE"
   cloud = "AWS"
   region =  "eu-central-1"
   standard {}
   environment {
     id = confluent_environment.environment.id
   }
     lifecycle {
    prevent_destroy = false
  }
 }

# --------------------------------------------------------
# Create Service Accounts  (admin, producer, consumer)
# --------------------------------------------------------

resource "confluent_service_account" "environment" {
  display_name = "${confluent_kafka_cluster.quickstart.display_name}-env"
  description = "Environment administrator services account"
}

resource "confluent_service_account" "admin" {
  display_name = "${confluent_kafka_cluster.quickstart.display_name}-admin"
  description = " Cluster administrator services account"
}

resource "confluent_service_account" "producer" {
  display_name = "${confluent_kafka_cluster.quickstart.display_name}-producer"
  description = "Service account that can write messages to the 'users' topic"
}

resource "confluent_service_account" "consumer" {
  display_name = "${confluent_kafka_cluster.quickstart.display_name}-consumer"
  description = "Service account that can read messages from the 'users' topic"
}

# --------------------------------------------------------
# Role Binding: environment, cluster admin, topic (producer, consumer)
# --------------------------------------------------------


resource "confluent_role_binding" "admin" {
    principal = "User:${confluent_service_account.admin.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.quickstart.rbac_crn
  
}

resource "confluent_role_binding" "producer" {
  principal   = "User:${confluent_service_account.producer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.quickstart.rbac_crn}/kafka=${confluent_kafka_cluster.quickstart.id}/topic=${confluent_kafka_topic.users.topic_name}"
}

resource "confluent_role_binding" "consumer" {
  principal   = "User:${confluent_service_account.consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.quickstart.rbac_crn}/kafka=${confluent_kafka_cluster.quickstart.id}/topic=${confluent_kafka_topic.users.topic_name}"
}

# --------------------------------------------------------
# Define API Key for Admin SA
# --------------------------------------------------------
resource "confluent_api_key" "admin" {
  display_name = "admin"
  description  = "Kafka API Key owned by the 'admin' service account"
  owner {
    id          = confluent_service_account.admin.id
    api_version = confluent_service_account.admin.api_version
    kind        = confluent_service_account.admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.quickstart.id
    api_version = confluent_kafka_cluster.quickstart.api_version
    kind        = confluent_kafka_cluster.quickstart.kind

    environment {
      id = confluent_environment.environment.id
    }
  }
  depends_on = [
    confluent_role_binding.admin
  ]
}
# --------------------------------------------------------
#  Create Topic (users)
# --------------------------------------------------------
resource "confluent_kafka_topic" "users" {
  kafka_cluster {
    id = confluent_kafka_cluster.quickstart.id
  }

  topic_name = "users"
  rest_endpoint = confluent_kafka_cluster.quickstart.rest_endpoint

  credentials {
    key = confluent_api_key.admin.id
    secret = confluent_api_key.admin.secret
  }

}


# --------------------------------------------------------
# 4. Connector(datagen_users)
# --------------------------------------------------------
resource "confluent_connector" "datagen_users" {
  environment {
    id = confluent_environment.environment.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.quickstart.id
  }

  config_sensitive = {}

  config_nonsensitive = {
    "connector.class"          = "DatagenSource"
    "name"                     = "DatagenUsers"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.producer.id
    "kafka.topic"              = confluent_kafka_topic.users.topic_name
    "output.data.format"       = "JSON"
    "quickstart"               = "USERS"
    "tasks.max"                = "1"
  }

  depends_on = [

  confluent_role_binding.producer
    
  ]

  lifecycle {
    prevent_destroy = true
  }
}

# --------------------------------------------------------
# KSQL 
# --------------------------------------------------------


# --------------------------------------------------------
# SR 
# --------------------------------------------------------