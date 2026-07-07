resource "layout" "two_pane" {
  column {
    width = "40"
    instructions {}
  }

  column {
    width = "60"

    tab "terminal" {
      target = resource.terminal.workstation
      title  = "Terminal"
    }

    tab "cursor_ide" {
      target = resource.service.cursor_ide
      title  = "Cursor IDE"
      active = true
    }
  }
}

resource "layout" "wrap_up" {
  column {
    width = "40"
    instructions {}
  }

  column {
    width = "60"

    tab "cursor_ide" {
      target = resource.service.cursor_ide
      title  = "Cursor IDE"
      active = true
    }
  }
}
