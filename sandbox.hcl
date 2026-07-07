resource "network" "main" {
  subnet = "10.60.0.0/24"
}

resource "container" "workstation" {
  image {
    name = "gcr.io/instruqt/shell"
  }

  resources {
    memory = 512
  }

  network {
    id      = resource.network.main.meta.id
    aliases = ["workstation"]
  }
}

resource "vm" "cursor" {
  image {
    name = "jparton-challenge/cursor-in-browser-vm"
  }

  resources {
    cpu    = 4
    memory = 8192
  }

  network {
    id      = resource.network.main.meta.id
    aliases = ["cursor"]
  }

  port {
    local = "8080"
  }

  startup_script = file("./scripts/setup-cursor.sh")
}

resource "terminal" "workstation" {
  target = resource.container.workstation
  shell  = "/bin/bash"
}

resource "service" "cursor_ide" {
  target = resource.vm.cursor
  scheme = "http"
  port   = 8080
  path   = "/"
}
