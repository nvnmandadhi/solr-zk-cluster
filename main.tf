provider "helm" {
  version = "~> 0.9"
  install_tiller = true
}

terraform {
  required_version = ">= 0.12"
  required_providers {
    google = "~> 3.9"
    null = "~> 2.1"
  }
}

provider "google" {
  project = "solstice-api-junkyard"
  region = "us-central1"
}

variable "istio_namespace" {
  default = "istio-system"
}

variable "istio_version" {
  default = "1.4.5"
}

variable "istio_url_version" {
  default = "https://storage.googleapis.com/istio-release/releases/1.4.5/charts/"
}

data "helm_repository" "istio" {
  name = "istio"
  url = var.istio_url_version
}

resource "helm_release" "istio_init" {
  name = "istio-init"
  repository = data.helm_repository.istio.url
  chart = "istio-init"
  version = var.istio_version
  namespace = var.istio_namespace
}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 80"
  }
  depends_on = [
    "helm_release.istio_init"]
}

resource "helm_release" "istio" {
  name = "istio"
  repository = data.helm_repository.istio.url
  chart = "istio"
  version = var.istio_version
  namespace = var.istio_namespace
  depends_on = [
    "null_resource.delay"
  ]

  values = [
    <<-EOF
     ingress:
       enable: "true"
       service:
         type: LoadBalanceryes
         externalHttpPort: 80
       deployment:
         name: ingress
         annotations:
           sidecar.istio.io/inject: "false"
           cloud.google.com/neg: '{"exposed_ports": {"80":{}}}'
       EOF
  ]

  set {
    name = "global.k8sIngressSelector"
    value = "ingressgateway"
  }
  set {
    name = "gateways.enabled"
    value = "true"
  }
  set {
    name = "gateways.istio-ingressgateway.type"
    value = "NodePort"
  }
}