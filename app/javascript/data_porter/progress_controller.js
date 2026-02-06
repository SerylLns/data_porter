import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["bar", "text"]
  static values = { id: Number }

  connect() {
    this.subscription = createConsumer().subscriptions.create(
      { channel: "DataPorter::ImportChannel", id: this.idValue },
      {
        received: (data) => {
          if (data.status === "processing") {
            this.updateProgress(data.percentage)
          } else {
            window.location.reload()
          }
        }
      }
    )
  }

  updateProgress(percentage) {
    if (this.hasBarTarget) {
      this.barTarget.style.width = `${percentage}%`
      this.textTarget.textContent = `${percentage}%`
    }
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }
}
