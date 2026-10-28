// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"

// Results page: while the server renders [data-analysis-poll], re-visit the page
// every 3 seconds. The server stops rendering it after 90 seconds or once the
// AI tips exist, so the loop ends by itself. No counter lives here.
let pollTimer

document.addEventListener("turbo:before-visit", () => clearTimeout(pollTimer))

document.addEventListener("turbo:load", () => {
  clearTimeout(pollTimer)
  if (!document.querySelector("[data-analysis-poll]")) return

  pollTimer = setTimeout(() => {
    Turbo.visit(window.location.href, { action: "replace" })
  }, 3000)
})
