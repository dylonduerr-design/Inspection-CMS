import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "targetContainer"]
  static values  = { projectLat: Number, projectLon: Number, shiftDate: String }

  connect() {
    console.log("👮 Maestro: ReportForm Controller Connected");
    this.initializeToggles();
    this.setupViewportDetection();
    this.autoFetchWeather();
  }

  disconnect() {
    this.teardownViewportDetection();
  }

  setupViewportDetection() {
    if (!window.matchMedia) return;

    this.mobileMediaQuery = window.matchMedia("(max-width: 768px)");
    this.handleViewportChange = this.handleViewportChange.bind(this);

    this.handleViewportChange(this.mobileMediaQuery);

    if (this.mobileMediaQuery.addEventListener) {
      this.mobileMediaQuery.addEventListener("change", this.handleViewportChange);
    } else {
      this.mobileMediaQuery.addListener(this.handleViewportChange);
    }
  }

  teardownViewportDetection() {
    if (!this.mobileMediaQuery || !this.handleViewportChange) return;

    if (this.mobileMediaQuery.removeEventListener) {
      this.mobileMediaQuery.removeEventListener("change", this.handleViewportChange);
    } else {
      this.mobileMediaQuery.removeListener(this.handleViewportChange);
    }
  }

  handleViewportChange(event) {
    const isMobileLayout = event.matches;
    const layout = isMobileLayout ? "mobile" : "desktop";
    const layoutChanged = this.currentLayout !== layout;

    this.element.dataset.layout = layout;
    document.documentElement.dataset.reportFormLayout = layout;

    if (layoutChanged) {
      this.applySectionLayoutState(layout);
      this.currentLayout = layout;
    }
  }

  applySectionLayoutState(layout) {
    const sections = this.element.querySelectorAll(".mobile-form-section");
    if (!sections.length) return;

    if (layout === "desktop") {
      sections.forEach((section) => {
        section.open = true;
      });
      return;
    }

    sections.forEach((section, index) => {
      section.open = index === 0;
    });
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

  // ---------------------------------------------------------------------------
  // resolveCoordinates()
  // Returns a Promise resolving to { lat, lon }.
  // Prefers stored project coordinates; falls back to browser geolocation.
  // ---------------------------------------------------------------------------
  resolveCoordinates() {
    if (this.projectLatValue && this.projectLonValue) {
      return Promise.resolve({ lat: this.projectLatValue, lon: this.projectLonValue });
    }
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error("Geolocation is not supported by this browser."));
        return;
      }
      navigator.geolocation.getCurrentPosition(
        (pos) => resolve({ lat: pos.coords.latitude, lon: pos.coords.longitude }),
        (err) => reject(err)
      );
    });
  }

  // ---------------------------------------------------------------------------
  // autoFetchWeather()
  // Called on connect(). Makes a single open-meteo hourly request for the
  // shift date and fills each weather slot whose target time is in the past
  // and whose fields are not already populated.
  // ---------------------------------------------------------------------------
  autoFetchWeather() {
    const shiftDate = this.shiftDateValue.replace(/^"|"$/g, ""); // strip any JSON-encoding quotes
    console.log("[Weather] autoFetchWeather | shiftDate:", shiftDate, "| lat:", this.projectLatValue, "| lon:", this.projectLonValue);
    if (!shiftDate) { console.log("[Weather] Skipped: no shiftDate"); return; }
    if (!this.projectLatValue || !this.projectLonValue) { console.log("[Weather] Skipped: no project coordinates"); return; }

    // Read shift_start and shift_end from the DOM time inputs
    const startInput = this.element.querySelector('[name="report[shift_start]"]');
    const endInput   = this.element.querySelector('[name="report[shift_end]"]');
    const startTime  = startInput ? startInput.value : ""; // "HH:MM"
    const endTime    = endInput   ? endInput.value   : "";
    console.log("[Weather] shift_start:", startTime, "| shift_end:", endTime);

    if (!startTime) { console.log("[Weather] Skipped: no shift_start"); return; }

    const parseHour = (t) => t ? parseInt(t.split(":")[0], 10) : null;
    const startHour = parseHour(startTime);
    const endHour   = parseHour(endTime);

    // Midpoint: round to nearest whole hour
    const midHour = (startHour !== null && endHour !== null)
      ? Math.round((startHour + endHour) / 2)
      : null;

    // Map suffix → target hour (null = skip this slot)
    const slotHours = { "1": startHour, "2": midHour, "3": endHour };

    // Current time in the format we'll compare against
    const now = new Date();
    const todayDate = now.toISOString().slice(0, 10); // "YYYY-MM-DD"
    const currentHour = now.getHours();

    // Determine which suffixes actually need filling
    const suffixesToFill = ["1", "2", "3"].filter(suffix => {
      const targetHour = slotHours[suffix];
      if (targetHour === null || targetHour === undefined) return false;

      // Only fill slots whose target time is in the past (or right now)
      // For past dates, all slots are always in the past
      const isPast = shiftDate < todayDate || (shiftDate === todayDate && targetHour <= currentHour);
      if (!isPast) return false;

      // Skip slots that are already fully populated
      const fields = ["temp", "weather_summary", "wind", "precip", "visibility"];
      const alreadyFilled = fields.every(f => {
        const input = this.element.querySelector(`[name="report[${f}_${suffix}]"]`);
        return input && input.value.trim() !== "";
      });
      return !alreadyFilled;
    });

    if (suffixesToFill.length === 0) { console.log("[Weather] Skipped: all slots either in the future or already filled"); return; }

    console.log("[Weather] Fetching hourly data for slots:", suffixesToFill, "| slotHours:", slotHours);
    const lat = this.projectLatValue;
    const lon = this.projectLonValue;
    const url = [
      `https://api.open-meteo.com/v1/forecast`,
      `?latitude=${lat}&longitude=${lon}`,
      `&hourly=temperature_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,visibility`,
      `&start_date=${shiftDate}&end_date=${shiftDate}`,
      `&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch`,
      `&timezone=auto`
    ].join("");

    fetch(url)
      .then(r => r.json())
      .then(data => {
        const h = data.hourly;
        if (!h || !h.time) return;

        const setVal = (namePart, suffix, value) => {
          const input = this.element.querySelector(`[name="report[${namePart}_${suffix}]"]`);
          if (input) input.value = value;
        };

        suffixesToFill.forEach(suffix => {
          const targetHour = slotHours[suffix];
          // Find the index in the time array matching our target hour on the shift date
          const idx = h.time.findIndex(t => t === `${shiftDate}T${String(targetHour).padStart(2, "0")}:00`);
          if (idx === -1) return;

          const temp    = h.temperature_2m[idx];
          const precip  = h.precipitation[idx];
          const code    = h.weather_code[idx];
          const speed   = h.wind_speed_10m[idx];
          const dir     = h.wind_direction_10m[idx];
          const vis     = h.visibility[idx];

          setVal("temp",            suffix, Math.round(temp));
          setVal("precip",          suffix, precip);
          setVal("weather_summary", suffix, this.decodeWeatherCode(code));
          setVal("wind",            suffix, `${Math.round(speed)} mph ${this.getCardinalDirection(dir)}`);

          if (vis !== undefined && vis !== null) {
            const visMiles = Math.min(vis / 1609.34, 10);
            setVal("visibility", suffix, `${visMiles.toFixed(1)} mi`);
          }

          // Show a subtle auto-filled label next to the column header
          const col = this.element.querySelector(`[data-suffix="${suffix}"]`)?.closest(".weather-col");
          if (col) {
            const existing = col.querySelector(".weather-auto-label");
            if (!existing) {
              const label = document.createElement("small");
              label.className = "weather-auto-label";
              label.style.cssText = "display:block; color:#6c757d; margin-top:4px; font-size:0.75rem;";
              label.textContent = `\uD83C\uDF24 Auto-filled for ${String(targetHour).padStart(2,"0")}:00`;
              col.querySelector("label").insertAdjacentElement("afterend", label);
            }
          }
        });
      })
      .catch(err => console.warn("Auto weather fetch failed:", err));
  }

  // ---------------------------------------------------------------------------
  // fetchWeather(event)  —  manual "Auto-Fill" button handler
  // Uses resolveCoordinates() then hits the current= endpoint for a live
  // real-time reading at the moment the inspector taps the button.
  // Always overwrites existing values.
  // ---------------------------------------------------------------------------
  fetchWeather(event) {
    event.preventDefault();
    const btn = event.target;
    const suffix = btn.dataset.suffix; // 1, 2, or 3
    const originalText = btn.innerText;

    btn.innerText = "Locating...";
    btn.disabled = true;

    this.resolveCoordinates()
      .then(({ lat, lon }) => this.performWeatherFetch(lat, lon, btn, suffix, originalText))
      .catch(err => {
        console.error(err);
        alert("Unable to retrieve location. Please set coordinates on the project or enable browser location.");
        btn.innerText = originalText;
        btn.disabled = false;
      });
  }

  performWeatherFetch(lat, lon, btn, suffix, originalText) {
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
          // Convert from meters to miles, cap at 10
          const cappedVisibility = Math.min(current.visibility / 1609.34, 10);
          setVal("visibility", `${cappedVisibility.toFixed(1)} mi`);
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
  //  SECTION 5: BID ITEM SELECTION LOGIC
  // =========================================================================
  
  // Triggered when a bid item is selected in the placed quantities section
  selectBidItem(event) {
    const select = event.target;
    const selectedOption = select.options[select.selectedIndex];
    const row = select.closest('.nested-fields');
    
    if (!row) return;

    const unitLabel = row.querySelector('.qty-unit');
    if (unitLabel) {
      unitLabel.textContent = selectedOption.dataset.unit || '';
    }
  }
}