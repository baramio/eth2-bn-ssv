terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}
provider "kubernetes" {
  config_path    = "baramio-kubeconfig.yaml"
}

variable "eth-cc-endpoint" {
  sensitive = true
}
variable "eth-ec-wss-endpoint" {
  sensitive = true
}
variable "operator-priv-key" {
  sensitive = true
}


resource "kubernetes_namespace" "ssv" {
  metadata {
    name = "ssv"
  }
}

resource "kubernetes_secret" "ssv-config" {
  metadata {
    name      = "ssv-config"
    namespace = "ssv"
  }
  data = {
    "config.yaml" = <<EOF
db:
  Path: /opt/ssv/data
# p2p:
  # replace with your ip
  # HostAddress: <<ssv-load-balancer-external-ip>>
eth2:
  Network: prater
  BeaconNodeAddr: ${var.eth-cc-endpoint}
eth1:
  ETH1Addr: ${var.eth-ec-wss-endpoint}
  RegistryContractAddr: 0x687fb596F3892904F879118e2113e1EEe8746C2E
  ETH1SyncOffset: 5367F4
OperatorPrivateKey: ${var.operator-priv-key}
global:
  LogLevel: debug
    EOF
  }
}


resource "kubernetes_stateful_set" "ssv-node" {
  metadata {
    name = "ssv"
    namespace = "ssv"
    labels = {
      app = "ssv-node"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ssv-node"
      }
    }
    template {
      metadata {
        labels = {
          app = "ssv-node"
        }
      }
      spec {
        container {
          image = "bloxstaking/ssv-node:latest"
          name  = "ssv-node"
          port {
            container_port = 12000
            name = "port-12000"
            protocol = "UDP"
          }
          port {
            container_port = 13000
            name = "port-13000"
          }
          port {
            container_port = 15000
            name = "port-15000"
          }
          args = ["make", "start-node"]
          env {
            name = "CONFIG_PATH"
            value = "/tmp/config.yaml"
          }
          volume_mount {
            name        = "config-volume"
            mount_path  = "/tmp"
            read_only  = true
          }
          volume_mount {
            mount_path = "/opt/ssv/data"
            name       = "ssvdata"
          }
        }
        volume {
          name = "config-volume"
          secret {
            secret_name = "ssv-config"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "ssvdata"
        namespace = "ssv"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "10Gi"
          }
        }
        storage_class_name = "do-block-storage"
      }
    }
    service_name = "ssv-node"
  }
}
