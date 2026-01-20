import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checklistModal", "questionsContainer", "template", "targetContainer"]

  connect() {
    console.log("👮 Maestro: ReportForm Controller Connected");
    this.initializeToggles();
  }

  // =========================================================================
  //  SECTION 1: TOGGLE LOGIC (Deficiencies, Safety, Additional Info)
  // =========================================================================
  
  // Triggered by data-action="change->report-form#toggleSection"
  toggleSection(event) {
    const trigger = event.target;
    const targetId = trigger.dataset.targetId;
    const validValues = JSON.parse(trigger.dataset.validValues || "[]");
    const targetElement = document.getElementById(targetId);

    if (!targetElement) return;

    // Logic: If checkbox, follow checked state. If radio, match value to validValues.
    let shouldShow = false;
    if (trigger.type === "checkbox") {
      shouldShow = trigger.checked;
    } else {
      shouldShow = validValues.includes(trigger.value);
    }

    // Use CSS class instead of inline styles
    if (shouldShow) {
      targetElement.classList.remove('d-none');
    } else {
      targetElement.classList.add('d-none');
    }

    // Optional: also toggle container styling (e.g., calm -> warning/danger)
    const containerId = trigger.dataset.containerId;
    const activeClass = trigger.dataset.activeClass;
    const inactiveClass = trigger.dataset.inactiveClass;

    if (containerId && activeClass && inactiveClass) {
      const containerEl = document.getElementById(containerId);
      if (containerEl) {
        if (shouldShow) {
          containerEl.classList.add(activeClass);
          containerEl.classList.remove(inactiveClass);
        } else {
          containerEl.classList.add(inactiveClass);
          containerEl.classList.remove(activeClass);
        }
      }
    }
  }

  // Run on load to set initial state based on existing DB values
  initializeToggles() {
    // We manually trigger the change event logic for any active inputs
    this.element.querySelectorAll('[data-action~="report-form#toggleSection"]').forEach(input => {
      if (input.type === "checkbox" && input.checked) {
        this.toggleSection({ target: input });
      } else if (input.type === "radio" && input.checked) {
        this.toggleSection({ target: input });
      }
    });
  }

  // =========================================================================
  //  SECTION 2: DYNAMIC ROWS (Crew, Equipment, QA, Inspection)
  // =========================================================================

  // Triggered by data-action="click->report-form#addAssociation"
  addAssociation(event) {
    event.preventDefault();
    
    // Get parameters from the button's dataset
    const templateId = event.target.dataset.templateId;
    const containerId = event.target.dataset.containerId;
    
    const template = document.getElementById(templateId);
    const container = document.getElementById(containerId);

    if (!template || !container) {
      console.error("Maestro Error: Missing template or container", { templateId, containerId });
      return;
    }

    // Clone and Timestamp
    const content = template.content.cloneNode(true);
    const uniqueId = new Date().getTime();

    content.querySelectorAll("input, select, textarea").forEach((el) => {
      el.name = el.name.replace("NEW_RECORD", uniqueId);
      // Clean up ID attributes to avoid duplicates
      if (el.id) el.id = el.id.replace("NEW_RECORD", uniqueId);
    });

    container.appendChild(content);

    // Auto-populate contractor if applicable
    if (event.target.dataset.populateContractor === "true") {
      this.syncContractorForNewRow(container.lastElementChild);
    }
  }

  // Triggered by data-action="click->report-form#removeAssociation"
  removeAssociation(event) {
    event.preventDefault();
    const row = event.target.closest(".nested-fields");
    
    // If it's a saved record, we need to find the _destroy hidden field
    const destroyInput = row.querySelector("input[name*='_destroy']");
    
    if (destroyInput) {
      destroyInput.value = "1";
      row.classList.add('d-none');
    } else {
      // If it's a new record (not saved yet), just remove from DOM
      row.remove();
    }
  }

  // =========================================================================
  //  SECTION 3: AUTO-POPULATION
  // =========================================================================

  syncContractorForNewRow(rowElement) {
    const mainContractor = document.getElementById("main-contractor-input");
    if (!mainContractor || !mainContractor.value) return;

    const rowInput = rowElement.querySelector(".auto-contractor");
    if (rowInput) {
      rowInput.value = mainContractor.value;
    }
  }

  // =========================================================================
  //  SECTION 4: WEATHER API
  // =========================================================================

  fetchWeather(event) {
    event.preventDefault();
    const btn = event.target;
    const suffix = btn.dataset.suffix; // 1, 2, or 3
    const originalText = btn.innerText;

    if (!navigator.geolocation) {
      alert("Geolocation is not supported by this browser.");
      return;
    }

    btn.innerText = "Locating...";
    btn.disabled = true;

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.performWeatherFetch(position, btn, suffix, originalText);
      },
      (error) => {
        console.error(error);
        alert("Unable to retrieve location.");
        btn.innerText = originalText;
        btn.disabled = false;
      }
    );
  }

  performWeatherFetch(position, btn, suffix, originalText) {
    const lat = position.coords.latitude;
    const lon = position.coords.longitude;
    btn.innerText = "Fetching...";

    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,visibility&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch`;

    fetch(url)
      .then(response => response.json())
      .then(data => {
        const current = data.current;
        
        // Helper to find inputs safely
        const setVal = (namePart, value) => {
          const input = this.element.querySelector(`[name="report[${namePart}_${suffix}]"]`);
          if (input) input.value = value;
        };

        setVal("temp", Math.round(current.temperature_2m));
        setVal("precip", current.precipitation);
        setVal("weather_summary", this.decodeWeatherCode(current.weather_code));

        if (current.visibility !== undefined && current.visibility !== null) {
          const visibilityMiles = current.visibility / 1609.34;
          setVal("visibility", `${visibilityMiles.toFixed(1)} mi`);
        }
        
        const windDir = this.getCardinalDirection(current.wind_direction_10m);
        setVal("wind", `${Math.round(current.wind_speed_10m)} mph ${windDir}`);

        btn.innerText = "✓ Updated";
        setTimeout(() => {
          btn.innerText = originalText;
          btn.disabled = false;
        }, 2000);
      })
      .catch(err => {
        console.error(err);
        btn.innerText = "Error";
        setTimeout(() => { btn.innerText = originalText; btn.disabled = false; }, 2000);
      });
  }

  getCardinalDirection(angle) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[Math.round(angle / 45) % 8];
  }

  decodeWeatherCode(code) {
    const codes = { 0: "Clear", 1: "Mainly Clear", 2: "Partly Cloudy", 3: "Overcast", 45: "Fog", 61: "Rain", 71: "Snow", 95: "Thunderstorm" };
    return codes[code] || "Unknown";
  }

  // =========================================================================
  //  SECTION 5: BID ITEM CHECKLIST LOGIC
  // =========================================================================
  
  // Triggered when a bid item is selected in the placed quantities section
  selectBidItem(event) {
    const select = event.target;
    const selectedOption = select.options[select.selectedIndex];
    const row = select.closest('.nested-fields');
    
    if (!row) return;
    
    const checklistBtn = row.querySelector('.checklist-btn');
    if (!checklistBtn) return;
    
    // Check if the selected bid item has an override checklist
    const hasOverride = selectedOption.dataset.hasOverride === 'true';
    
    // Show/hide the checklist button based on whether there's an override
    if (hasOverride) {
      checklistBtn.classList.remove('d-none');
    } else {
      checklistBtn.classList.add('d-none');
    }
  }

  // Placeholder for opening the checklist modal (if implemented)
  openChecklist(event) {
    event.preventDefault();
    console.log("Open checklist functionality - to be implemented");
  }

  // Placeholder for closing the checklist modal (if implemented)
  closeModal(event) {
    if (event) event.preventDefault();
    console.log("Close modal functionality - to be implemented");
  }

  // Placeholder for saving checklist answers (if implemented)
  saveChecklist(event) {
    if (event) event.preventDefault();
    console.log("Save checklist functionality - to be implemented");
  }
}