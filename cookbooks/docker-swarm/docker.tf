provider "softlayer" {}

data "softlayer_ssh_key" "my_key" {
    label = "${var.ssh_key_label}"
}

resource "softlayer_virtual_guest" "manager" {
    name              = "docker-swarm-manager"
    domain            = "demo.com"
    os_reference_code = "UBUNTU_LATEST"
    datacenter        = "${var.datacenter}"
    cpu               = 1
    ram               = 1024
    local_disk        = true

    ssh_keys = [
        "${data.softlayer_ssh_key.my_key.id}"
    ]

    provisioner "remote-exec" {
        script = "docker.sh"
    }

    provisioner "local-exec" {
        command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${self.ipv4_address} 'docker swarm join-token -q worker' > token.txt"
    }
}

resource "softlayer_virtual_guest" "worker" {
    count             = "${var.worker_count}"
    name              = "docker-swarm-worker${count.index}"
    domain            = "demo.com"
    os_reference_code = "UBUNTU_LATEST"
    datacenter        = "${var.datacenter}"
    cpu               = 1
    ram               = 1024
    local_disk        = true

    ssh_keys = [
        "${data.softlayer_ssh_key.my_key.id}"
    ]

    provisioner "remote-exec" {
        inline = [
            "apt-get update -y",
            "apt-get install docker.io curl -y",
            "curl -L http://bit.ly/2ejTiG7 | bash -s",
            "ufw allow 2377/tcp",
            "ufw allow 4789/tcp",
            "ufw allow 7946/tcp",
            "docker swarm join --token ${file("token.txt")} ${softlayer_virtual_guest.manager.ipv4_address}:2377"
        ]
    }
}
