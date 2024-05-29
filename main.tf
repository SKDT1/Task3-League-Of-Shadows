/*You must complete the following scenerio.


A) European gaming company is moving to GCP. It has the following requirements in
it's first stage migration to the Cloud:


A) You must choose a region in Europe to host it's prototype gaming information.  
This page must only be on a RFC 1918 Private 10 net and can't be accessible from the Internet.


B) The Americas must have 2 regions and both must be RFC 1918 172.16 based subnets.  
They can peer with HQ in order to view the homepage however, they can only view the page on port 80.


C) Asia Pacific region must be choosen and it must be a RFC 1918 192.168 based subnet.  
This subnet can only VPN into HQ.  Additionally, only port 3389 is open to Asia. No 80, no 22.


Deliverables.
1) Complete Terraform for the entire solution.
2) Git Push of the solution to your GitHub.
3) Screenshots showing how the HQ homepage was accessed from both the Americas and Asia Pacific.*/



#############################################
#CREATE 1 VPC & 4 SUBNETS w/ Firewall Rules #
#############################################


resource "google_compute_network" "eurohq" {
  name                    = "thenarrowpath"
  routing_mode            = "REGIONAL"
  auto_create_subnetworks = false
}


# This is HQ, page only on RFC 1918 Private 10 and no access to internet
resource "google_compute_subnetwork" "eurosubnet1" {
  name          = "eurosub1"
  description   = "Finland-European Gaming Company"  
  ip_cidr_range = "10.160.12.0/24" #must be private
  region        = "europe-north1"
  private_ip_google_access = true
  network       = google_compute_network.eurohq.id
}


# 2 Americas RFC 1918 172.16 Subnets, peering only on port 80
resource "google_compute_subnetwork" "namerica-subnet2" {
  name          = "namericasub2"
  description   = "North America-SouthCarolina"
  ip_cidr_range = "172.16.7.0/24"
  region        = "us-east1"
  private_ip_google_access = true
  network       = google_compute_network.eurohq.id
   
}


resource "google_compute_subnetwork" "samerica-subnet3" {
  name          = "samericasub3"
  description   = "South America-Sao Paulo"
  ip_cidr_range = "172.16.8.0/24"
  region        = "southamerica-east1"
  private_ip_google_access = true
  network       = google_compute_network.eurohq.id
  
}


# Asia Pacific Region, w/ RFC 1918 192.168 subnet. subnet only VPN into HQ, only port 3389. no 80 or 22
resource "google_compute_subnetwork" "asia-subnet4" {
  name          = "asiasub4"
  description   = "Taiwan"
  ip_cidr_range = "192.168.9.0/24"
  region        = "asia-east1"
  private_ip_google_access = true
  network       = google_compute_network.eurohq.id
  
}

###########  Instances ##############

#Euro Instance
resource "google_compute_instance" "eurohq2" {
  depends_on   = [google_compute_subnetwork.eurosubnet1]
  name         = "europ-hq"
  machine_type = "e2-medium"
  zone         = "europe-north1-a"


  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.eurohq.id
    subnetwork = google_compute_subnetwork.eurosubnet1.id

    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }

  metadata = {
    startup-script = file("${path.module}/startup-script.sh")
  }
 
  tags = ["europe-webserver"]
}


#Americas Instances
resource "google_compute_instance" "namerica2" {
  depends_on   = [google_compute_subnetwork.namerica-subnet2]
  name         = "namerica-instance"
  machine_type = "e2-medium"
  zone         = "us-east1-b"


  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }


  network_interface {
    network    = google_compute_network.eurohq.id
    subnetwork = google_compute_subnetwork.namerica-subnet2.id


    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }


  tags = ["nsamerica-webservers", "iap-ssh-allowed"]


}
resource "google_compute_instance" "samerica" {
  depends_on   = [google_compute_subnetwork.samerica-subnet3]
  name         = "samerica-instance"
  machine_type = "n2-standard-4"
  zone         = "southamerica-east1-c"

  boot_disk {
    initialize_params {
      image = "projects/windows-cloud/global/images/windows-server-2022-dc-v20240415"
    }
  }

  network_interface {
    network    = google_compute_network.eurohq.id
    subnetwork = google_compute_subnetwork.samerica-subnet3.id
    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }
  tags = ["nsamerica-webservers"]
}

##Asia Instance

resource "google_compute_instance" "asia-insta1" {
  depends_on   = [google_compute_subnetwork.asia-subnet4]
  name         = "asia-instance"
  machine_type = "n2-standard-4"
  zone         = "asia-east1-a"


  boot_disk {
    initialize_params {
      image = "projects/windows-cloud/global/images/windows-server-2022-dc-v20240415"
    }
  }
  network_interface {
    network    = google_compute_network.eurohq.id
    subnetwork = google_compute_subnetwork.asia-subnet4.id

    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }
  tags = ["asia-remote-server"]
}

#########FIREWALL RULES#######################

resource "google_compute_firewall" "alloweuro_http" {
  name    = "alloweuro-http"
  network = google_compute_network.eurohq.id


  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["10.160.12.0/24", "172.16.7.0/24", "172.16.8.0/24", "192.168.9.0/24"]
  target_tags   = ["europe-webserver", "nsamerica-webservers", "asia-remote-server"]
#source_ranges = ["0.0.0.0/0", "35.235.240.0/20"]
}


# Americas firewall rules for Americas to Allow Port 80 Traffic coke
resource "google_compute_firewall" "allow_port_80" {
  name    = "allow-port-80"
  network = google_compute_network.eurohq.id
 
  allow {
    protocol = "tcp"
    ports    = ["80", "22", "3389"]
   
  }
  source_ranges = ["0.0.0.0/0", "35.235.240.0/20"]
   target_tags   = ["nsamerica-webservers", "iap-ssh-allowed"]
}


# Asia Pacific firewall rules to allow port 3389, open to Asia. No 80, no 22
resource "google_compute_firewall" "allow_port_3389" {
  name    = "allow-port-3389"
  network = google_compute_network.eurohq.id
 
  allow {
    protocol = "tcp"
    ports    = ["3389"]
   
  }
  source_ranges = ["0.0.0.0/0"]
}


#############################################
# Create VPNs, Static IP, FORWARDING RULES  #
#############################################


resource "google_compute_vpn_gateway" "narrowgate1" {
  name    = "europevpn"
  region  = "europe-north1"
  network = google_compute_network.eurohq.id
}
# Static IP Address, check GUI, or find output command
resource "google_compute_address" "europe-static" {
  name   = "euro-static-ip"
  description = "share ip part"
  region = "europe-north1"
  address_type = "EXTERNAL"
}
 
#FORWARDING RULES FOR EUROPE (ESP, UPD 500 & UPD 4500 Rules)
 resource "google_compute_forwarding_rule" "europe_esp" {
  name        = "eu-esp"
  region      = "europe-north1"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.europe-static.address
  target      = google_compute_vpn_gateway.narrowgate1.id
}


resource "google_compute_forwarding_rule" "europe-udp500" {
  name        = "eu-udp500"
  region      = "europe-north1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.europe-static.address
  port_range  = "500"
  target      = google_compute_vpn_gateway.narrowgate1.id
}


resource "google_compute_forwarding_rule" "europe-udp4500" {
  name        = "eu-udp4500"
  region      = "europe-north1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.europe-static.address
  port_range  = "4500"
  target      = google_compute_vpn_gateway.narrowgate1.id
}


resource "google_compute_vpn_gateway" "narrowgate2" {
  name    = "asiavpn"
  region  = "asia-east1"
  network = google_compute_network.eurohq.id
}


########### Static IP Address, check GUI, or find output command
resource "google_compute_address" "asia-static" {
  name   = "asia-static-ip"
  description = "share ip part"
  region = "asia-east1"
}


#FORWARDING RULES FOR ASIA (ESP, UPD 500 & UPD 4500 Rules)
 resource "google_compute_forwarding_rule" "asia_esp" {
  name        = "asia-esp"
  region      = "asia-east1"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.asia-static.address
  target      = google_compute_vpn_gateway.narrowgate2.id
}


resource "google_compute_forwarding_rule" "asia-udp500" {
  name        = "asia-udp500"
  region      = "asia-east1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.asia-static.address
  port_range  = "500"
  target      = google_compute_vpn_gateway.narrowgate2.id
}


resource "google_compute_forwarding_rule" "asia-udp4500" {
  name        = "asia-udp4500"
  region      = "asia-east1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.asia-static.address
  port_range  = "4500"
  target      = google_compute_vpn_gateway.narrowgate2.id
}

######### Create Tunnels ############

resource "google_compute_vpn_tunnel" "vpntunnel1" {
  name               = "euro-to-asia-tunnel"
  region             = "europe-north1"
  target_vpn_gateway = google_compute_vpn_gateway.narrowgate1.id
  peer_ip            = google_compute_address.asia-static.address # Asia VPN Static IP
  shared_secret      = "sharedsecret"          # Replace with your shared secret .secret_data?
  ike_version        = 2


  local_traffic_selector  = ["10.160.12.0/24"]
  remote_traffic_selector = ["192.168.9.0/24"]


  depends_on = [
    google_compute_forwarding_rule.europe_esp,
    google_compute_forwarding_rule.europe-udp500,
    google_compute_forwarding_rule.europe-udp4500
  ]
}


resource "google_compute_vpn_tunnel" "vpntunnel2" {
  name               = "asia-2-euro-tunnel"
  region             = "asia-east1"
  target_vpn_gateway = google_compute_vpn_gateway.narrowgate2.id
  peer_ip            = google_compute_address.europe-static.address # Euro VPN static IP
  shared_secret      = "sharedsecret"          # Replace with your shared secret .secret_data?
  ike_version        = 2


  local_traffic_selector  = ["192.168.9.0/24"]
  remote_traffic_selector = ["10.160.12.0/24"]


  depends_on = [
    google_compute_forwarding_rule.asia_esp,
    google_compute_forwarding_rule.asia-udp500,
    google_compute_forwarding_rule.asia-udp4500
  ]
}

resource "google_compute_router" "router1" {
  name        = "vpn-router1"
  description = "Europe HQ"
  region      = "europe-north1"
  network     = google_compute_network.eurohq.id
 
}

resource "google_compute_router" "router2" {
  name        = "vpn-router2"
  region      = "asia-east1"
  description = "Asian Pacific"
  network     = google_compute_network.eurohq.id
}

#Outputs

output "europe_vpn_ip_address" {
  value = google_compute_address.europe-static.address
}

output "asia_vpn_ip_address" {
  value = google_compute_address.asia-static.address
}


output "europe_vm_internal_ip" {
  description = "Internal IP address of the Europe VM"
  value       = google_compute_instance.eurohq2.network_interface[0].network_ip
}
