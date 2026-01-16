import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "detective" ]

  connect() {
    console.log("🐞 UI Controller Connected")
    this.restoreTheme()
  }

  // --- DARK MODE LOGIC ---
  toggleTheme() {
    // 1. Check the BODY class (Source of Truth)
    const isDark = document.body.classList.contains('dark-mode')
    
    // 2. Determine the NEW state (If dark, make light. If light, make dark)
    const newTheme = isDark ? 'light' : 'dark'

    console.log(`🌗 Toggling Theme: Was ${isDark ? 'Dark' : 'Light'} -> Becoming ${newTheme}`)
    
    // 3. Force Apply
    this.applyTheme(newTheme)
    localStorage.setItem('theme', newTheme)
  }

  restoreTheme() {
    const savedTheme = localStorage.getItem('theme') || 'light'
    console.log(`📂 Restoring Theme: ${savedTheme}`)
    this.applyTheme(savedTheme)
  }

  applyTheme(theme) {
    // Force the HTML attribute to match
    document.documentElement.setAttribute('data-theme', theme)
    
    // Force the Body class to match
    if (theme === 'dark') {
      document.body.classList.add('dark-mode')
    } else {
      document.body.classList.remove('dark-mode')
    }
  }

  // --- DETECTIVE LOGIC ---
  toggleDetective() {
    this.detectiveTarget.classList.toggle("detective-hidden")
  }
}