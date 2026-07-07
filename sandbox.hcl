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

resource "container" "cursor" {
  image {
    name = "arfodublo/cursor-in-browser:latest-x64"
  }

  environment = {
    CUSTOM_PORT = "8080"
    TITLE       = "Cursor AI — Order Processing API"
    DISPLAY     = ":1"
    BROWSER     = "chromium"
  }

  resources {
    cpu    = 4000
    memory = 8192
  }

  network {
    id      = resource.network.main.meta.id
    aliases = ["cursor"]
  }

  port {
    local = "8080"
  }
}

resource "exec" "setup_cursor" {
  target  = resource.container.cursor
  script  = "./scripts/setup-cursor.sh"
  timeout = "300s"

  run_as {
    user  = "root"
    group = "root"
  }
}

resource "terminal" "workstation" {
  target = resource.container.workstation
  shell  = "/bin/bash"
}

resource "service" "cursor_ide" {
  target = resource.container.cursor
  scheme = "http"
  port   = 8080
  path   = "/"
}
