resource "page" "welcome_setup" {
  title = "Welcome & Setup"
  file  = "instructions/welcome-setup.md"
}

resource "page" "explore_codebase" {
  title = "Explore the Codebase"
  file  = "instructions/explore-codebase.md"
}

resource "page" "trace_data_flow" {
  title = "Trace a Data Flow"
  file  = "instructions/trace-data-flow.md"

  activities = {
    order_type_quiz = resource.quiz.order_type_quiz
  }
}

resource "page" "extend_integration" {
  title = "Extend the Integration"
  file  = "instructions/extend-integration.md"
}

resource "page" "wrap_up" {
  title = "Wrap-Up"
  file  = "instructions/wrap-up.md"
}
