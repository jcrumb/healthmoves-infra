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
}

resource "random_id" "db_suffix" {
	byte_length = 4
}

resource "google_sql_database_instance" "healthmoves_db_instance" {
	name = "healthmoves-${random_id.db_suffix.hex}"
	database_version = "MYSQL_5_7"
	settings {
		tier = "db-n1-standard-1"
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

output "password" {
	value = "${random_string.db_app_user_password.result}"
}

output "ip" {
	value = "${google_compute_instance.ml_dev_box.network_interface.0.access_config.0.nat_ip}"
}

