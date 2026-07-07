resource "single_choice_question" "order_type_default" {
  question = "What happens to `orderType` in `normalize-order.dwl` if no order type is present in the inbound payload?"

  answer = "It is set to \"retail\" by default if missing, and lowercased before routing"

  distractors = [
    "It is passed through unchanged from the inbound payload",
    "It is looked up from the customer profile during enrichment",
    "It is always set to \"express\" for gold and platinum tier customers",
  ]
}

resource "quiz" "order_type_quiz" {
  questions = [resource.single_choice_question.order_type_default]
}
