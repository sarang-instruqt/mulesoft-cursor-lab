resource "lab" "main" {
  title       = "Explore and Extend MuleSoft with Cursor AI"
  description = "Use Cursor AI Agents to understand and extend a real MuleSoft integration project — no MuleSoft account required."
  layout      = resource.layout.two_pane

  tags = ["ai", "dataweave", "integration", "mulesoft", "cursor"]

  settings {
    theme = "modern-dark"

    timelimit {
      duration   = "60m"
      show_timer = true
    }

    idle {
      enabled = true
      timeout = "15m"
    }

    controls {
      show_stop = false
    }
  }

  content {
    title = "Explore and Extend MuleSoft with Cursor AI"

    chapter "welcome_setup" {
      title = "Welcome & Setup"

      page "welcome_setup" {
        reference = resource.page.welcome_setup
      }
    }

    chapter "explore_codebase" {
      title = "Explore the Codebase"

      page "explore_codebase" {
        reference = resource.page.explore_codebase
      }
    }

    chapter "trace_data_flow" {
      title = "Trace a Data Flow"

      page "trace_data_flow" {
        reference = resource.page.trace_data_flow
      }
    }

    chapter "extend_integration" {
      title = "Extend the Integration"

      page "extend_integration" {
        reference = resource.page.extend_integration
      }
    }

    chapter "wrap_up" {
      title = "Wrap-Up"

      page "wrap_up" {
        reference = resource.page.wrap_up
        layout    = resource.layout.wrap_up
      }
    }
  }
}
