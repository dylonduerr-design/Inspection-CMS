// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "pwa"

document.addEventListener("turbo:load", function() {
  document.documentElement.classList.add("js-enabled")
})