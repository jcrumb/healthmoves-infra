provider "google" {
	project = "healthmoves"
	region = "northamerica-northeast1"
	zone = "northamerica-northeast1-a"
}

data "google_compute_image" "ml-dev-image" {
	family = "ubuntu-1804-lts"
	project = "gce-uefi-images"
}

resource "google_compute_instance" "ml-dev-box" {
	name = "ml-dev-server"
	machine_type = "n1-standard-1"
	boot_disk {
		initialize_params {
			image = "${data.google_compute_image.ml-dev-image.self_link}"
		}
	}
	network_interface {
		network = "default"
		access_config {}
	}
}
