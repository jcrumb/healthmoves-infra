provider "google" {
	project = "healthmoves"
	region = "northamerica-northeast1"
	zone = "northamerica-northeast1-a"
}

data "google_compute_image" "ml_dev_image" {
	family = "ubuntu-1804-lts"
	project = "gce-uefi-images"
}

resource "google_compute_instance" "ml_dev_box" {
	name = "ml-dev-server"
	machine_type = "n1-standard-1"
	boot_disk {
		initialize_params {
			image = "${data.google_compute_image.ml_dev_image.self_link}"
		}
	}
	network_interface {
		network = "default"
		access_config {}
	}
	metadata = {
		sshKeys = "moves:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCWv04gdPHWU+6A611irsUgQrS2rbrRxXHdMT0ZmDgJ7lv5NZoICz2pnNS39OhpvZjyQYWx7fmVD/mQSdYXVvpr5nDWRnaGddSP2O8mLOYCHp2QTjxLIGRYG3BEr8LODeu6zrGKUbabTmhe8372m+I43QBF35vfEjbo9InsfWlzPKMEl3j/P2T6/4V1XZqSSFQIqqfGnRPNHbsBm5N+zQmTWmcWNLPOuziPF/GqPOzYWIjQ3QFVUPzEg+v0iuIvzwTEA3k+OIYBs25wVHYxPh4Yfla8D7zKSc4zTlCDmOMl8CCnRMx/swJumJ8LxHhrTGoEb9Kh8L4dm9qacXZMoGXn j\nmoves:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVdG3sN87wcPMnJVei8xOUToQgL7qauZEZdYLjfRGULR0e3TvJarwATl+Z7kKRCBs1g+XWa7zrxvhKIPQb0iW0n7YD/ooO9kF7JXMvfuJqJVv4nvEia7NBe5rBTEQno0aAbTBJwRZ8S3tDN/v0DhD46MDth8Avfd/+aYRsO7tV56R2tUme7wQmOmiSyAcOSEuuk6fqcRxYrQNl04/7ubzgioB/KlD44VnlpkJIzwgrb35Nkj+yBklRXl+Dvr3e5gubdw5SMJS/O3zqK8O2Yqrz1c1FnlsmtiUNjUZu5Dbx3aCaW10RrTrfOwDvfFRdWf06VIG8IldMlTLMXJ9ideZJNDGr+3qYg94yZ+/uc9n5+4tPdf9uSCvzS4ScZnTmuk0qKK6Pb40Se6QDp5Zig6BKmLzlpUMBz+44++mnprLei6WU1+kshso5tVT+0vo2y+MYZzVIMYQ8HkP7fUSVsXRs+9apzhSgUREI/suDCeqaWPg4mbEGy0rpGMAIwleGD/M= a\nssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDi63qi4Rx+h+vjlZMv/EXwdP8arYhM+MO94td2cSbmiEk/KhJakTSTCI2A0T0NlrZw4o8KXxWlt6jq2AXZHXoTL/GLydj/G2zFuAHm6qT2LgmH04auvRN9lyZ78v1ckQ8UaU6/1zNRiLkyhQ9twkbHmcl676fXxJQfIRY7qD43o5H4RYSR9UxgxiAA1/fy00ITA/N+ycGmprs/76BDPBPbQLuQcXCP4oW2ZX1khP+0iQgmJXA0Hg0sFp20hTPUEgAolgEQl9G2eTr5M3kUivEL9/Duqz4t1TVPyv8rsMLt7QX4UiOuU1kcl63ASRcLBLx6k42DYgbf25nJHruk/Y9d e"
	}
}

resource "random_id" "db_suffix" {
	byte_length = 4
}

resource "google_sql_database_instance" "healthmoves_db_instance" {
	# append a 4 byte suffix to the end of the db, useful when creating/destroying a lot
	# during development, as when a google cloud sql instance is destroyed the name
	# may remain unusable for up to a week afterwards.
	name = "healthmoves-${random_id.db_suffix.hex}"
	database_version = "MYSQL_5_7"
	settings {
		tier = "db-g1-small"
		ip_configuration {
		      authorized_networks {
			      value = "0.0.0.0/0"
			      name = "global"
		      }
	    	}
	}
}

resource "google_sql_database" "healthmoves" {
	name = "healthmoves"
	instance = "${google_sql_database_instance.healthmoves_db_instance.name}"
	charset = "utf8"
	collation = "utf8_general_ci"
}

resource "random_string" "db_app_user_password" {
	length = 41
	special = true
}

resource "google_sql_user" "healthmoves_db_user" {
	name = "healthmoves"
	instance = "${google_sql_database_instance.healthmoves_db_instance.name}"
	host = "%"
	password = "${random_string.db_app_user_password.result}"
}

resource "google_pubsub_topic" "healthmoves_msg_queue" {
	name = "healthmoves"
}

resource "random_string" "k8s_master_password" {
	length = 30
	special = false
}

resource "google_container_cluster" "healthmoves_kubernetes_cluster" {
	name = "healthmoves-k8s"
	remove_default_node_pool = true
	initial_node_count = 1

	master_auth {
		username = "healthmoves-master"
		password = "${random_string.k8s_master_password.result}"
	}
}

resource "google_container_node_pool" "kubernetes_node_pool" {
	name = "healthmoves-node-pool"
	cluster = "${google_container_cluster.healthmoves_kubernetes_cluster.name}"
	node_count = 1
	node_config {
		preemptible = false
		machine_type = "n1-standard-1"
		oauth_scopes = [
		      "https://www.googleapis.com/auth/logging.write",
		      "https://www.googleapis.com/auth/monitoring",
    		]
		metadata = {
		      disable-legacy-endpoints = "true"
	        }
	}
}

output "k8s_password" {
	description = "Kubernetes master password"
	value = "${random_string.k8s_master_password.result}"
}

output "password" {
	description = "DB user password"
	value = "${random_string.db_app_user_password.result}"
}

output "ip" {
	description = "Dev box IP"
	value = "${google_compute_instance.ml_dev_box.network_interface.0.access_config.0.nat_ip}"
}

