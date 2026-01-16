// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// CHANGED: We use 'turbo:load' instead of 'DOMContentLoaded'
document.addEventListener("turbo:load", function() {
  
  // --- Detective Toggle Logic ---
  const detectiveToggleBtn = document.getElementById("detective-toggle-btn");
  const detectiveWindow = document.getElementById("detective-window");

  // We check if elements exist to avoid errors on pages where they might be missing
  if (detectiveToggleBtn && detectiveWindow) {
    // Remove existing listeners if any (clean up to be safe, though Turbo usually handles fresh elements)
    // Actually, since the element is fresh from the DOM swap, we can just add the listener.
    detectiveToggleBtn.addEventListener("click", function() {
      detectiveWindow.classList.toggle("detective-hidden");
    });
  }

  // --- Dark Mode Logic ---
  const themeBtn = document.getElementById("theme-toggle-btn");
  const htmlDoc = document.documentElement;

  if (themeBtn) {
    themeBtn.addEventListener("click", function() {
      const currentTheme = htmlDoc.getAttribute("data-theme");
      const newTheme = currentTheme === "dark" ? "light" : "dark";
      
      htmlDoc.setAttribute("data-theme", newTheme);
      localStorage.setItem("theme", newTheme);
    });
  }
});