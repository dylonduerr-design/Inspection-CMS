# db/seeds.rb

puts "🌱 Maestro: Cleaning old data..."
WeeklyReport.destroy_all
ImportedReport.destroy_all
ApprovedEquipment.destroy_all
ChecklistEntry.destroy_all
PlacedQuantity.destroy_all
QaEntry.destroy_all
CrewEntry.destroy_all
EquipmentEntry.destroy_all
ReportAttachment.destroy_all
ReportExport.destroy_all
Report.destroy_all
AuditLog.destroy_all
BidItem.destroy_all
SpecItem.destroy_all
Project.destroy_all
Phase.destroy_all
User.destroy_all

puts "👤 Maestro: Creating Users..."
admin = User.find_or_create_by!(email: "admin@cms.com") do |u|
  u.password = "cloudattack"
  u.password_confirmation = "cloudattack"
  u.role = :qc
end

tester = User.find_or_create_by!(email: "tester@cms.com") do |u|
  u.password = "cloudattack"
  u.password_confirmation = "cloudattack"
  u.role = :inspector
end

# Dylon Duerr
User.find_or_create_by!(email: "dd@cms.com") do |u|
  u.password = "Tester_4312!"
  u.password_confirmation = "Tester_4312!"
  u.role = :admin
end

# Braulio Hinojos
User.find_or_create_by!(email: "bh@cms.com") do |u|
  u.password = "Tester_4312!"
  u.password_confirmation = "Tester_4312!"
  u.role = :admin
end

# Daniel Castillo
User.find_or_create_by!(email: "dc@cms.com") do |u|
  u.password = "Admin_4312!"
  u.password_confirmation = "Admin_4312!"
  u.role = :admin
end

# Joshua Alcantara
User.find_or_create_by!(email: "ja@cms.com") do |u|
  u.password = "Admin_4312!"
  u.password_confirmation = "Admin_4312!"
  u.role = :admin
end

puts "🏗️  Maestro: Building Projects..."
project_1 = Project.find_or_create_by!(name: "Runway 1R Rehabilitation") do |p|
  p.contract_number = "8983.61"
  p.prime_contractor = "Granite Construction Company"
  p.project_manager = "Anthony Lum, PE"
  p.construction_manager = "Joshua Alcantara, PE"
  p.contract_days = 89
  p.contract_start_date = Date.new(2025, 9, 24)
end

project_2 = Project.find_or_create_by!(name: "Taxiway Charlie Reconstruction") do |p|
  p.contract_number = "9001.45"
  p.prime_contractor = "Flatiron Construction Corp"
  p.project_manager = "Sarah Martinez, PE"
  p.construction_manager = "David Chen, PE"
  p.contract_days = 120
  p.contract_start_date = Date.new(2025, 10, 1)
end

puts "📅 Maestro: Building Phases..."
phase_1 = Phase.find_or_create_by!(name: "Phase 1 - Demolition")
(2..6).each { |i| Phase.find_or_create_by!(name: "Phase #{i}") }
finalized_phase = Phase.find_or_create_by!(name: "Phase 3")

puts "📘 Maestro: Building FAA Spec Library with Enhanced Question Schema..."

# Helper to build question objects using the new schema
def build_question(prompt, kind: "radio", options: nil, **attrs)
  SpecItem.build_question(prompt: prompt, kind: kind, options: options, **attrs)
end

# Default checklist questions in new object format
default_questions = [
  build_question("Material submittals approved?"),
  build_question("Weather conditions acceptable?"),
  build_question("Equipment clean and functional?"),
  build_question("Grade and alignment checked?"),
  build_question("Safety requirements met?"),
  build_question("Photos taken?")
]

# P-401 Asphalt specific questions with mixed field types
p401_questions = [
  build_question("Mix design ID", kind: "text", placeholder: "Enter mix design ID"),
  build_question("Lot #", kind: "number", placeholder: "Enter lot number", validation: { min: 0, step: 1 }),
  build_question("Lift thickness per plan", kind: "number", placeholder: "Enter thickness", validation: { min: 0, step: 0.1 }),
  build_question(
    "Is the surface dry and above minimum temperature per 401-4.1 table 4?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain why the surface condition was not acceptable." }]
  ),
  build_question(
    "Was the surface properly cleaned prior to applying tack coat? 401-4.11",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain surface cleaning issues." }]
  ),
  build_question(
    "Are haul trucks clean? 401-4.4",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain haul truck issues." }]
  ),
  build_question(
    "Were approved release agents used on all equipment? 401-4.4",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain release agent issues." }]
  ),
  build_question(
    "Were QC personnel onsite to monitor production using nuclear density gauges? 401-4.7",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain QC personnel coverage." }]
  ),
  build_question(
    "Were edges of existing pavement sawcut in accordance with 401-4.12 p.4?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain sawcut deviations." }]
  ),
  build_question(
    "Are the minimum lane width requirements met per plan except as allowed per 401-4.12 p.5?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain lane width deviations." }]
  ),
  build_question(
    "Were longitudinal and transverse joints offset by the minimum necessary per 401-4.12 p.6?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain joint offset deviations." }]
  ),
  build_question(
    "Did any segment of paving exhibit segregation requiring removal per 401-4.12 p.8?",
    followups: [{ value: "Yes", label: "Explain", placeholder: "Describe segregation and removal." }]
  ),
  build_question(
    "Was the rolling plan implemented as such that no undue displacement, cracking, or shoving of the asphalt mat occurred per 401-4.13 p.1?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain rolling plan issues." }]
  ),
  build_question(
    "Was rolling equipment sufficiently furnished and moistened with water as necessary during compaction operations per 401-4.13 p.2?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain rolling equipment issues." }]
  ),
  build_question(
    "In areas inaccessible to rolling equipment, were powered tampers used to compact asphalt per 401-4.13 p.3?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain compaction method used." }]
  ),
  build_question(
    "Were tapered edges placed in accordance with 401-4.14 p.2 as necessary?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain tapered edge deviations." }]
  ),
  build_question(
    "Have longitudinal joints that have been exposed for more than four hours, cool to less than 175 degrees F, or are otherwise defective been cut back in accordance with 401-4.14 p.3?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain joint cutback issues." }]
  ),
  build_question(
    "If heating equipment is used, does it meet the requirements set in 401-4.14 p.4-6?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain heating equipment issues." }]
  ),
  build_question(
    "If paving at night, did the contractor provide adequate lighting in accordance with the lighting plan approved by the RPR per 401-4.17?",
    followups: [{ value: "No", label: "Explain", placeholder: "Explain lighting issues." }]
  ),
  build_question(
    "Did the contractor deviate from the approved paving plan? If yes, explain (layout change per ASO request, plant or equipment breakdown, inclement weather, etc.)",
    followups: [{ value: "Yes", label: "Explain", placeholder: "Explain the paving plan deviation." }]
  )
]

# P-403 Asphalt Mix Pavement [Base/Leveling/Surface] - Comprehensive checklist
p403_questions = [
  build_question("Mix design ID", kind: "text", placeholder: "Enter mix design ID"),
  build_question("Lot #", kind: "number", placeholder: "Enter lot number", validation: { min: 0, step: 1 }),
  build_question("Lift thickness per plan", kind: "number", placeholder: "Enter thickness", validation: { min: 0, step: 0.1 }),
  build_question("Is the surface dry and above minimum temperature per 403-4.1 table 4?"),
  build_question("Was the surface properly cleaned prior to applying tack coat? 403-4.10"),
  build_question("Are haul trucks clean? 403-4.3"),
  build_question("Were approved release agents used on all equipment? 403-4.4"),
  build_question("Were QC personnel onsite to monitor production using nuclear density gauges? 403-4.6.1"),
  build_question("Were edges of existing pavement sawcut in accordance with 403-4.11 p.4?"),
  build_question("Are the minimum lane width requirements met per plan except as allowed per 403-4.11 p.6?"),
  build_question("Were longitudinal and transverse joints offset by the minimum necessary per 403-4.11 p.8?"),
  build_question("Did any segment of paving exhibit segregation, contamination, overheated asphalt mixture or insufficiently coated aggregate requiring removal per 403-4.11 p.9?"),
  build_question("Was the rolling plan implemented as such that no undue displacement, cracking, or shoving of the asphalt mat occurred per 403-4.12 p.1?"),
  build_question("Was rolling equipment sufficiently furnished and moistened with water as necessary during compaction operations per 403-4.12 p.2?"),
  build_question("In areas inaccessible to rolling equipment, were powered tampers used to compact asphalt per 403-4.12 p.3?"),
  build_question("Were tapered edges placed in accordance with 403-4.13 p.2 as necessary?"),
  build_question("Have longitudinal joints that have been exposed for more than four hours, cool to less than 175 degrees F, or are otherwise defective been cut back in accordance with 403-4.13 p.3?"),
  build_question("If heating equipment is used, does it meet the requirements set in 403-4.13 p.4-6?"),
  build_question("If paving at night, did the contractor provide adequate lighting in accordance with the lighting plan approved by the RPR per 403-4.16?"),
  build_question("Did the contractor deviate from the approved paving plan? If yes, explain (layout change per ASO request, plant or equipment breakdown, inclement weather, etc.)")
]

# P-501 PCC specific questions with mixed field types
p501_questions = [
  build_question("Material submittals approved?"),
  build_question("Subgrade/subbase prepared and approved?"),
  build_question("Concrete temperature (°F)", kind: "number", placeholder: "Enter temperature",
                 validation: { min: 50, max: 90 }),
  build_question("Slump (inches)", kind: "number", placeholder: "Enter slump value",
                 validation: { min: 0, max: 8, step: 0.25 }),
  build_question("Air content (%)", kind: "number", placeholder: "Enter air content",
                 validation: { min: 3, max: 8, step: 0.5 }),
  build_question("Cylinder specimens taken?"),
  build_question("Number of cylinders", kind: "number", placeholder: "Enter count",
                 validation: { min: 0, max: 20 }),
  build_question("Curing compound applied?"),
  build_question("Joint sawing timing acceptable?"),
  build_question("Placement notes", kind: "textarea", placeholder: "Enter placement observations..."),
  build_question("Photos taken?")
]

# P-101 Pavement Removal checklist
p101_questions = [
  build_question("Has the removal operation been controlled to prevent damage to adjacent pavement, base material, and utilities that are to remain? - 101-3.1"),
  build_question("Is asphalt pavement being cut to the full depth around the perimeter of the removal area? - 101-3.1b"),
  build_question("If asphalt material is being wasted on the airport site, is it broken to a maximum size of 1 inch? - 101-3.1b"),
  build_question("Is the joint for each layer of pavement replacement offset 1 foot from the joint in the preceding layer (unless otherwise shown on plans)? - 101-3.1b"),
  build_question("Is all failed material (surface, base, subbase, and subgrade) being removed and repaired as shown on the plans or as directed by the RPR? - 101-3.1c"),
  build_question("Is damage caused by the Contractor's removal process being repaired at the Contractor's expense? - 101-3.1c"),
  build_question("Is milling producing a uniform finished surface? - 101-3.5"),
  build_question("Is the milling machine operating without tearing or gouging the underlaying surface? - 101-3.5"),
  build_question("Is the milling machine equipped with automatic grade/slope controls and positive dust control? - 101-3.5"),
  build_question("Are all millings being removed and disposed of off Airport property (or used/stockpiled as specified)? - 101-3.5"),
  build_question("Is the milling machine cutting vertical edges without chipping or spalling the remaining pavement edges? - 101-3.5a"),
  build_question("Does the milling machine have a minimum width of 7 feet and electronic grade control devices? - 101-3.5b"),
  build_question("Is the machine cutting vertical edges and using positive dust control? - 101-3.5b"),
  build_question("Does the machine have the ability to windrow or remove millings and load them into a truck? - 101-3.5b"),
  build_question("Is the milled surface being swept daily and immediately after milling until all residual materials are removed? - 101-3.5c"),
  build_question("Prior to paving, is the milled pavement being wetted down and thoroughly swept/blown to loosen residual material? - 101-3.5c"),
  build_question("Are waste materials being collected and removed from the pavement surface and adjacent areas by sweeping or vacuuming? - 101-3.5c"),
  build_question("Are asphalt pavement surfaces softened by petroleum or failed areas being patched? - 101-3.6a"),
  build_question("Is damaged pavement removed to full depth and replaced with new asphalt pavement similar to existing? - 101-3.6a"),
  build_question("Are joints and cracks being repaired in accordance with paragraph 101-3.2? - 101-3.6b"),
  build_question("Is oil or grease being removed by scrubbing with detergent and washing with clean water? - 101-3.6c"),
  build_question("Are cleaned oil/grease areas being treated with oil spot primer? - 101-3.6c"),
  build_question("Is the pavement surface clean and free of dust, dirt, grease, vegetation, oil, or objectionable film immediately prior to surface treatment? - 101-3.6d"),
  build_question("Is the Contractor performing maintenance to keep pavement in satisfactory condition until acceptance? - 101-3.7"),
  build_question("Is the surface being kept clean and free from foreign material? - 101-3.7"),
  build_question("Is the pavement being kept properly drained at all times? - 101-3.7"),
  build_question("Are joints being cleaned and dried of all scale, dirt, dust, old sealant, curing compound, moisture, and foreign matter prior to sealing? - 101-3.8"),
  build_question("Has the Contractor demonstrated to the RPR that the cleaning method cleans the joint without damaging it? - 101-3.8")
]

# P-151 Clearing and Grubbing checklist
p151_questions = [
  build_question("Are the clearing/grubbing limits properly staked on the ground as shown on the plans? - 151-2.1"),
  build_question("Is clearing and grubbing being performed sufficiently in advance of grading operations? - 151-2.1"),
  build_question("Are all cleared materials being disposed of outside the airport limits (unless otherwise directed by RPR)? - 151-2.1.1"),
  build_question("Are any discarded materials being left in windrows or piles adjacent to or within the airport limits? (Verify NONE exist) - 151-2.1.1"),
  build_question("Has the RPR approved the disposal manner and location? Does the disposal area create an unsightly or objectionable view? - 151-2.1.1"),
  build_question("If using private property for disposal, has written permission from the property owner been obtained and filed with the RPR? - 151-2.1.1"),
  build_question("Is blasting being used for any clearing operations? (Verify NONE) - 151-2.1.2"),
  build_question("Has the staked area been cleared of all objectionable materials as indicated on the plans? - 151-2.2"),
  build_question("Have any trees that fell outside the clearing limits been cut up, removed, and disposed of satisfactorily? - 151-2.2"),
  build_question("Are trees being felled toward the center of the area being cleared to protect standing trees? - 151-2.2"),
  build_question("Are all trees designated to remain protected from injury during clearing operations? - 151-2.2"),
  build_question("Are trees, stumps, and brush cut flush with the original ground surface? - 151-2.2"),
  build_question("Is fence wire neatly rolled and properly stored as directed by the RPR? - 151-2.2"),
  build_question("In cleared and grubbed areas (excluding deep embankment zones outside paved areas), have all stumps, roots, buried logs, brush, grass, and unsatisfactory materials been removed? - 151-2.3"),
  build_question("In embankment areas outside paved areas, are sound trees, stumps, and brush cut flush with original ground and allowed to remain? - 151-2.3"),
  build_question("Are tap roots and projections over 1-1/2 inches diameter grubbed out to at least 18 inches below finished subgrade or slope elevation? - 151-2.3"),
  build_question("Have all buildings and structures shown on plans for removal been demolished/removed with all materials disposed of off-site? - 151-2.3"),
  build_question("Have foundations, wells, cesspools, and similar structures been broken down to at least 2 feet below existing ground level? - 151-2.3"),
  build_question("Has objectionable material that cannot be used in backfill been removed and properly disposed of? - 151-2.3"),
  build_question("Have holes and openings from removed structures been backfilled with acceptable material and properly compacted? - 151-2.3"),
  build_question("Do holes in embankment areas have flattened sides to facilitate filling and compaction per P-152? - 151-2.3"),
  build_question("In areas where grubbing holes exceed proposed excavation depth, have the hole sides been flattened for proper backfilling? - 151-2.3")
]

# P-603 Emulsified Asphalt Tack Coat checklist
p603_questions = [
  build_question("Is the existing surface dry at the time of application? - 603-3.1"),
  build_question("Is the atmospheric temperature 50°F or above and are weather conditions free from fog and rain at the time of application? - 603-3.1"),
  build_question("If temperature requirements are waived, is written direction from the RPR on file? - 603-3.1"),
  build_question("Is the equipment in good working order? - 603-3.2"),
  build_question("Is the distributor tank free of contaminants and diluents? - 603-3.2"),
  build_question("Are spray bar tips clean and free of burrs? - 603-3.2"),
  build_question("Is the application speed maintained under 8 mph (700 ft/min)? - 603-3.2"),
  build_question("Are predetermined flow rates and constant pressure maintained during application? - 603-3.2"),
  build_question("Is the surface cleaned of all dust, dirt, loose material, and foreign matter immediately before application? - 603-3.3"),
  build_question("Is the surface dry before application of the tack coat? - 603-3.3"),
  build_question("Does the tack coat provide uniform coverage without streaks? - 603-3.4"),
  build_question("Does the tack coat provide uniform coverage without bare spots? - 603-3.4"),
  build_question("Has the tack coat broken (water evaporated leaving asphalt residue) before asphalt mixture placement? - 603-3.4")
]

# P-610 Concrete for Miscellaneous Structures checklist
p610_questions = [
  build_question("Is slump tested per ASTM C143 and not exceeding 4 inches (100 mm)? - 610-3.2"),
  build_question("Have all forms and reinforcements been inspected and approved by RPR before concrete placement? - 610-3.4"),
  build_question("Are forms true to line and grade, mortar-tight, and rigid (no displacement or sagging)? - 610-3.4"),
  build_question("Are form surfaces smooth and free from irregularities, dents, sags, and holes? - 610-3.4"),
  build_question("Are internal form ties arranged so no metal shows or discolors the concrete surface after form removal? - 610-3.4"),
  build_question("Is reinforcement accurately placed per plans and firmly held in position during placement? - 610-3.5"),
  build_question("Is concrete dropped from a height of 5 feet (1.5 m) or less? - 610-3.8"),
  build_question("Is vibration being performed in accordance with ACI 309R guidelines? - 610-3.9"),
  build_question("When placing concrete below 40°F (4°C), are ACI 306R cold weather concreting recommendations being followed? - 610-3.13"),
  build_question("When placing concrete above 85°F (30°C), are ACI 305R hot weather concreting recommendations being followed? - 610-3.14")
]

# P-219 Recycled Concrete Aggregate Base Course checklist
p219_questions = [
  build_question("Has the subgrade been compacted to the required density prior to base course placement? - 219-3.1"),
  build_question("Is each lift of base course 8 inches (200 mm) or less in compacted thickness? - 219-3.3"),
  build_question("Is the material placed to the lines, grades, and cross-sections shown on the plans? - 219-3.3"),
  build_question("Is material being placed and compacted within 24 hours of delivery to the site? - 219-3.3"),
  build_question("Is the compacted base course achieving a minimum of 95% of maximum density (ASTM D1557)? - 219-3.4"),
  build_question("Is the moisture content within +/- 2% of optimum moisture content prior to rolling? - 219-3.4"),
  build_question("Are areas failing to meet specified density being reworked and re-compacted until density requirements are achieved? - 219-3.4"),
  build_question("Is the finished surface smooth and free from ruts, depressions, or irregularities? - 219-3.5"),
  build_question("Are areas failing smoothness, grade, or crown requirements being scarified to at least 3 inches (75 mm), reshaped, and re-compacted? - 219-3.6"),
  build_question("Are all final smoothness and grade checks being performed in the presence of the RPR? - 219-3.6"),
  build_question("Does the finished surface vary no more than +/- 1/2 inch (12 mm) when tested with a 12-foot straightedge? - 219-3.6(a)"),
  build_question("Is grade and crown being measured on a 50-foot grid? - 219-3.6(b)"),
  build_question("Is the measured grade and crown within +/- 0.05 feet (15 mm) of the specified grade? - 219-3.6(b)"),
  build_question("Is the base course thickness within +0 and -1/2 inch (12 mm) of specified thickness? - 219-3.8"),
  build_question("Are depth tests for thickness being taken by the Contractor in the presence of the RPR? - 219-3.8"),
  build_question("Are areas deficient by more than 1/2-inch (12 mm) being removed to full depth and replaced at Contractor's expense? - 219-3.8"),
  build_question("Are surveys being conducted before and after base placement on a minimum 25ft x 25ft grid (if survey method is used for thickness)? - 219-3.8")
]

# P-620 Marking specific questions
p620_questions = [
  build_question("Surface clean and dry?"),
  build_question("Layout approved?"),
  build_question("Paint type/color verified?"),
  build_question("Film thickness (mils)", kind: "number", placeholder: "Enter thickness",
                 validation: { min: 10, max: 25 }),
  build_question("Glass beads applied?"),
  build_question("Bead application rate (lbs/gal)", kind: "number", placeholder: "Enter rate",
                 validation: { min: 5, max: 15, step: 0.5 }),
  build_question("Drying time observed (minutes)", kind: "number", placeholder: "Enter time"),
  build_question("Retroreflectivity reading", kind: "number", placeholder: "Enter mcd/m²/lux"),
  build_question("Photos taken?")
]

faa_specs = {
  "Part 1 – General Provisions" => {
    "P-101" => { desc: "Pavement Removal", questions: p101_questions },
    "P-102" => { desc: "Seeding and Mulching", questions: default_questions },
    "P-151" => { desc: "Clearing and Grubbing", questions: p151_questions },
  },
  "Part 2 – Earthwork and Drainage" => {
    "P-209" => { desc: "Aggregate Base Course", questions: default_questions },
    "P-210" => { desc: "Aggregate Drainage Course", questions: default_questions },
    "P-219" => { desc: "Recycled Concrete Aggregate Base Course", questions: p219_questions },
  },
  "Part 3 – Sitework" => {
    "P-152" => { desc: "Excavation, Subgrade, and Embankment", questions: default_questions },
    "P-154" => { desc: "Soil Stabilization with Portland Cement", questions: default_questions },
  },
  "Part 4 – Rigid Pavements" => {
    "P-501" => { desc: "Portland Cement Concrete Pavement", questions: p501_questions },
    "P-502" => { desc: "Continuously Reinforced Portland Cement Concrete Pavement", questions: p501_questions },
  },
  "Part 5 – Stabilized Pavements" => {
    "P-304" => { desc: "Aggregate Stabilization", questions: default_questions },
    "P-306" => { desc: "Cement Treated Base Course", questions: default_questions },
  },
  "Part 6 – Flexible Pavements" => {
    "P-401" => { desc: "Asphalt Mix Pavement", questions: p401_questions },
    "P-403" => { desc: "Asphalt Mix Pavement [Base/Leveling/Surface]", questions: p403_questions },
  },
  "Part 7 – Drainage and Utilities" => {
    "P-253" => { desc: "Storm Drainage Pipe", questions: default_questions },
    "P-254" => { desc: "Drainage Structures and Appurtenances", questions: default_questions },
  },
  "Part 8 – Lighting and Electrical" => {
    "P-610" => { desc: "Concrete for Miscellaneous Structures", questions: p610_questions },
    "P-611" => { desc: "Airfield Lighting Equipment", questions: default_questions },
  },
  "Part 9 – Miscellaneous" => {
    "P-620" => { desc: "Runway and Taxiway Marking", questions: p620_questions },
    "P-603" => { desc: "Emulsified Asphalt Tack Coat", questions: p603_questions },
    "P-625" => { desc: "Pavement Grooving", questions: default_questions },
  }
}

faa_specs.each do |division, items|
  items.each do |code, config|
    SpecItem.find_or_create_by!(code: code) do |spec|
      spec.description = config[:desc]
      spec.division = division
      spec.checklist_questions = config[:questions]
    end
  end
end

puts "💰 Maestro: Linking Bid Items..."
p401_bid_item = nil
p501_bid_item = nil

# Bid quantities (expected amounts per bid) keyed by FAA code
bid_quantities = {
  "P-101" => 1_000,     # LS items often 1
  "P-152" => 50_000,    # CY earthwork
  "P-209" => 45_000,    # CY subbase
  "P-210" => 10_000,    # CY borrow
  "P-304" => 35_000,    # CY aggregate base
  "P-306" => 12_000,    # CY CTB
  "P-401" => 80_000,    # SY asphalt
  "P-403" => 10_000,    # SY intermediate
  "P-501" => 60_000,    # SY PCC
  "P-502" => 8_000,     # SY PCC overlay/repair
  "P-603" => 90_000,    # Gal tack or SY equivalent
  "P-610" => 18_000,    # LF joint sealing
  "P-620" => 25_000,    # LF pavement markings
  "P-625" => 15_000     # LF grooving
}

puts "   → Project 1 Bid Items (All Divisions)..."
faa_specs.each do |division, items|
  items.each do |code, config|
    spec = SpecItem.find_by(code: code)
    next unless spec
    
    bid_item = BidItem.find_or_create_by!(
        project: project_1,
        code: "RW1R-#{code}",
        spec_item: spec
      ) do |bi|
        bi.description = spec.description
        bi.unit = case code
              when "P-401", "P-403", "P-501", "P-502" then "SY"
              when "P-152", "P-209", "P-210", "P-304", "P-306" then "CY"
              when "P-620", "P-625", "P-610" then "LF"
              when "P-101" then "LS"
              else "EA"
              end
        bi.bid_quantity = bid_quantities[code]
        bi.checklist_questions = spec.checklist_questions
      end
    
    p401_bid_item = bid_item if code == "P-401"
  end
end

puts "   → Project 2 Bid Items (All Divisions)..."
faa_specs.each do |division, items|
  items.each do |code, config|
    spec = SpecItem.find_by(code: code)
    next unless spec
    
    bid_item = BidItem.create!(
      project: project_2,
      code: "TWC-#{code}",
      description: spec.description,
      unit: case code
            when "P-401", "P-403", "P-501", "P-502" then "SY"
            when "P-152", "P-209", "P-210", "P-304", "P-306" then "CY"
            when "P-620", "P-625", "P-610" then "LF"
            when "P-101" then "LS"
            else "EA"
            end,
      bid_quantity: bid_quantities[code],
      spec_item: spec,
      checklist_questions: spec.checklist_questions
    )
    
    p501_bid_item = bid_item if code == "P-501"
  end
end

puts "🛠️  Maestro: Adding Approved Equipment to Projects..."

# Project 1 Equipment with Categories
{
  "General Equipment" => ["JD 210 Skiploader", "Wirtgen 210h Miller"],
  "Excavation and Embankment" => ["Caterpillar D6 Dozer", "Volvo L120 Loader", "John Deere 850K Dozer"],
  "Asphalt Paving" => ["Caterpillar AP1000 Paver", "Wirtgen W210 Cold Mill", "Bomag BW213 Roller"],
  "Specialty" => ["CAT Paver"]
}.each do |category, equipment_list|
  equipment_list.each do |name|
    ApprovedEquipment.create!(project: project_1, name: name, category: category)
  end
end

# Project 2 Equipment with Categories
{
  "General Equipment" => ["Hitachi ZX350 Excavator"],
  "Excavation and Embankment" => ["Caterpillar 320 Excavator", "Terex TA400 Haul Truck"],
  "Asphalt Paving" => ["Caterpillar AP600 Paver", "Roadtec RX700e Paver", "Bomag BW177 Roller", "Hamm HD120 Roller"],
  "Specialty" => []
}.each do |category, equipment_list|
  equipment_list.each do |name|
    ApprovedEquipment.create!(project: project_2, name: name, category: category)
  end
end

puts "📝 Maestro: Generating Sample Report for Project 1..."
report = Report.create(
  user: admin,
  project: project_1,
  phase: phase_1,
  dir_number: "001",
  start_date: Date.today,
  status: :in_progress,
  result: :pending,
  shift_start: "07:00",
  shift_end: "15:30",
  contractor: "Granite Construction Company",
  
  temp_1: 65, weather_summary_1: "Clear", wind_1: "5mph N", precip_1: "0", visibility_1: "10+ miles",
  temp_2: 72, weather_summary_2: "Sunny", wind_2: "8mph NW", precip_2: "0", visibility_2: "10+ miles",
  temp_3: 68, weather_summary_3: "Clear", wind_3: "6mph N", precip_3: "0", visibility_3: "10+ miles",
  surface_conditions: "Dry pavement, no standing water. Surface temperature within acceptable range for paving operations.",
  
  deficiency_status: :no_deficiency,
  safety_incident: :safety_na,
  traffic_control: :tc_yes,
  environmental: :env_yes,
  security: :sec_yes,
  air_ops_coordination: :air_yes,
  swppp_controls: :swppp_yes,
  phasing_compliance: :phase_yes,
  
  commentary: "Asphalt paving operations commenced at 0730 hours following pre-work safety briefing and toolbox talk. Granite Construction crew mobilized paving equipment including Caterpillar AP1000 paver, breakdown roller, and finish rollers. Tack coat application completed and inspected prior to paving. Mix temperature verified at plant and monitored throughout placement. Paving progressed from Station 10+00 to Station 15+00 with consistent mat thickness and density. Rolling pattern followed approved submittal with breakdown, intermediate, and finish rolling achieving target densities. Joint construction at transverse joints met specifications. Weather conditions remained favorable throughout shift with temperatures conducive to proper compaction. No deficiencies noted. All safety protocols observed including proper PPE usage and traffic control maintenance.",
  
  additional_activities: "Pre-paving meeting held at 0700 to review daily operations plan and safety requirements. Conducted quality control testing including nuclear density gauge readings at three locations along the placement area. All readings met or exceeded 95% of maximum theoretical density. Coordinated with airport operations regarding runway closure schedule and phasing requirements.",
  
  additional_info: "Material delivery schedules reviewed with plant operator to ensure continuous paving operations for next shift. Discussed upcoming weather forecast with contractor - potential rain event forecasted for next week may impact schedule."
)

CrewEntry.create!(
  report: report,
  contractor: "Granite Construction Company",
  superintendent_count: 1,
  foreman_count: 2,
  operator_count: 4,
  laborer_count: 6,
  notes: "Full paving crew including paver operator, roller operators, and laborers for material transfer and hand work at joints."
)

EquipmentEntry.create!(
  report: report,
  contractor: "Granite Construction Company",
  make_model: "Caterpillar AP1000 Paver",
  quantity: 1,
  hours: 8.0
)

EquipmentEntry.create!(
  report: report,
  contractor: "Granite Construction Company",
  make_model: "Bomag BW213 Roller (Breakdown)",
  quantity: 1,
  hours: 7.5
)

if p401_bid_item
  PlacedQuantity.create!(
    report: report,
    bid_item: p401_bid_item,
    quantity: 500.0,
    location: "Sta 10+00 to 15+00, Runway 1R centerline",
    notes: "First lift asphalt placement, 2.5 inch compacted thickness. Mat temperatures ranged from 290-310°F at laydown.",
    checklist_answers: { 
      "material_submittals_approved_1" => "Yes", 
      "tack_coat_applied_and_broken_2" => "Yes",
      "surface_temperature_f_3" => 145,
      "mat_temperature_at_laydown_f_4" => 305,
      "compacted_lift_thickness_inches_5" => 2.5,
      "rolling_pattern_observed_6" => "Yes",
      "joint_construction_acceptable_7" => "Yes",
      "core_sample_location_8" => "Sta 12+50, 25' left of centerline",
      "photos_taken_10" => "Yes"
    }
  )
end

QaEntry.create!(
  report: report,
  qa_type: :nuclear_gauge,
  location: "Sta 11+25, 15' right of centerline",
  result: :qa_pass,
  remarks: "Density 96.2% of max theoretical. Target: 95% minimum."
)

puts "📋 Maestro: Creating Sample Report for Project 2..."
report_2 = Report.create(
  user: admin,
  project: project_2,
  phase: phase_1,
  dir_number: "002",
  start_date: Date.today - 5.days,
  status: :review,
  result: :pass,
  shift_start: "06:00",
  shift_end: "14:30",
  contractor: "Flatiron Construction Corp",
  
  temp_1: 58, weather_summary_1: "Partly Cloudy", wind_1: "10mph SW", precip_1: "0", visibility_1: "10+ miles",
  temp_2: 68, weather_summary_2: "Clear", wind_2: "12mph W", precip_2: "0", visibility_2: "10+ miles",
  temp_3: 71, weather_summary_3: "Sunny", wind_3: "14mph W", precip_3: "0", visibility_3: "10+ miles",
  surface_conditions: "Subbase clean, dry, and properly compacted. Moisture content within specification limits.",
  
  deficiency_status: :no_deficiency,
  safety_incident: :safety_na,
  traffic_control: :tc_yes,
  environmental: :env_yes,
  security: :sec_yes,
  air_ops_coordination: :air_yes,
  swppp_controls: :swppp_yes,
  phasing_compliance: :phase_yes,
  
  commentary: "Portland cement concrete pavement placement operations conducted between Station 5+00 and Station 8+50 on Taxiway Charlie. Pre-construction meeting held at 0545 hours covering concrete mix design, placement procedures, and quality control requirements. Subgrade inspection completed and approved prior to concrete delivery. First concrete truck arrived on site at 0630 hours. Slump tests performed on initial load measured 3.5 inches, within specified range of 2-4 inches. Air content testing verified at 5.5%, meeting specification requirement of 5-8%. Concrete placement proceeded using slip-form paver with consistent forward progress. Finishing operations included float finishing, texturing per approved pattern, and application of curing compound immediately following finishing. Ambient temperature remained within acceptable range throughout placement. Six cylinder sets collected for compression testing at 7, 14, and 28 days. Joint sawing initiated four hours after placement, with timing verified to prevent random cracking. All QC test results met specifications. Weather conditions favorable with no precipitation and adequate temperature for proper curing.",
  
  additional_activities: "Coordinated concrete truck delivery schedule with batch plant to maintain continuous placement operations. Monitored concrete temperature throughout placement to ensure compliance with specification limits. Verified proper installation of dowel bars at transverse joints per plan details.",
  
  additional_info: "Next phase of paving scheduled to begin in three days pending completion of joint sealing and curing period for today's placement. Reviewed revised traffic control plan with airport operations to accommodate upcoming work areas."
)

CrewEntry.create!(
  report: report_2,
  contractor: "Flatiron Construction Corp",
  superintendent_count: 1,
  foreman_count: 1,
  operator_count: 3,
  laborer_count: 8,
  notes: "Concrete paving crew including slip-form paver operator, finishing crew, and laborers for material handling and edge work."
)

EquipmentEntry.create!(
  report: report_2,
  contractor: "Flatiron Construction Corp",
  make_model: "Gomaco GP2400 Slip-Form Paver",
  quantity: 1,
  hours: 7.5
)

EquipmentEntry.create!(
  report: report_2,
  contractor: "Flatiron Construction Corp",
  make_model: "Soff-Cut 5000 Early Entry Saw",
  quantity: 2,
  hours: 4.0
)

if p501_bid_item
  PlacedQuantity.create!(
    report: report_2,
    bid_item: p501_bid_item,
    quantity: 350.0,
    location: "Taxiway Charlie, Sta 5+00 to 8+50",
    notes: "14-inch PCC pavement, Type P mix design. Joint spacing at 15-foot intervals per plan.",
    checklist_answers: { 
      "material_submittals_approved_1" => "Yes", 
      "subgradesubbase_prepared_and_approved_2" => "Yes",
      "concrete_temperature_f_3" => 72,
      "slump_inches_4" => 3.5,
      "air_content__5" => 5.5,
      "cylinder_specimens_taken_6" => "Yes",
      "number_of_cylinders_7" => 6,
      "curing_compound_applied_8" => "Yes",
      "joint_sawing_timing_acceptable_9" => "Yes",
      "placement_notes_10" => "Placement proceeded smoothly with consistent mat thickness. Finishing operations completed per specification. Curing compound applied at manufacturer's recommended rate.",
      "photos_taken_11" => "Yes"
    }
  )
end

QaEntry.create!(
  report: report_2,
  qa_type: :concrete_slump,
  location: "Initial truck, Sta 5+00",
  result: :qa_pass,
  remarks: "Slump: 3.5 inches. Target range: 2-4 inches."
)

QaEntry.create!(
  report: report_2,
  qa_type: :concrete_cylinder,
  location: "Sta 6+50",
  result: :qa_pass,
  remarks: "Six cylinder sets collected for 7, 14, and 28 day breaks."
)

puts "📋 Maestro: Creating Reports for Tester User..."
phase_2 = Phase.find_by(name: "Phase 2")
p209_bid_item = BidItem.find_by(project: project_1, code: "RW1R-P-209")

report_3 = Report.create(
  user: tester,
  project: project_1,
  phase: phase_2,
  dir_number: "003",
  start_date: Date.today - 2.days,
  status: :in_progress,
  result: :pending,
  shift_start: "06:30",
  shift_end: "15:00",
  contractor: "Granite Construction Company",
  
  temp_1: 62, weather_summary_1: "Overcast", wind_1: "8mph NE", precip_1: "0", visibility_1: "8 miles",
  temp_2: 70, weather_summary_2: "Partly Cloudy", wind_2: "10mph E", precip_2: "0", visibility_2: "10+ miles",
  temp_3: 68, weather_summary_3: "Partly Cloudy", wind_3: "9mph E", precip_3: "0", visibility_3: "10+ miles",
  surface_conditions: "Subgrade prepared and moisture conditioned. No soft spots or pumping observed during proof rolling.",
  
  deficiency_status: :no_deficiency,
  safety_incident: :safety_na,
  traffic_control: :tc_yes,
  environmental: :env_yes,
  security: :sec_yes,
  air_ops_coordination: :air_yes,
  swppp_controls: :swppp_yes,
  phasing_compliance: :phase_yes,
  
  commentary: "Aggregate base course installation progressed from Station 20+00 to Station 25+00. Material delivered from approved source and verified against approved gradation. Moisture content checked prior to placement and adjusted as needed for optimal compaction. Base course placed in two lifts of 6 inches each using motor grader for spreading and shaping. Each lift compacted using vibratory smooth drum roller followed by pneumatic tire roller to achieve uniform density. Nuclear density gauge testing performed at regular intervals with all readings exceeding 98% of maximum dry density per modified Proctor. Grade and cross-slope verified using string line and level at 50-foot intervals. All measurements within tolerance. Weather conditions favorable for base course operations with adequate moisture in material. No deficiencies noted during placement or testing.",
  
  additional_activities: "Proof rolling conducted on completed sections using loaded tandem axle dump truck to identify any areas of insufficient support. No deflection or pumping observed. Coordinated with material supplier to ensure adequate stockpile for tomorrow's operations.",
  
  additional_info: "Base course operations scheduled to continue tomorrow weather permitting. Final lift will bring section to grade for prime coat application."
)

CrewEntry.create!(
  report: report_3,
  contractor: "Granite Construction Company",
  superintendent_count: 1,
  foreman_count: 1,
  operator_count: 5,
  laborer_count: 7,
  notes: "Base course crew including motor grader operator, roller operators, water truck operator, and laborers for grade verification and hand work."
)

EquipmentEntry.create!(
  report: report_3,
  contractor: "Granite Construction Company",
  make_model: "Caterpillar 140M Motor Grader",
  quantity: 1,
  hours: 7.5
)

EquipmentEntry.create!(
  report: report_3,
  contractor: "Granite Construction Company",
  make_model: "Bomag BW177 Vibratory Roller",
  quantity: 1,
  hours: 7.0
)

if p209_bid_item
  PlacedQuantity.create!(
    report: report_3,
    bid_item: p209_bid_item,
    quantity: 450.0,
    location: "Runway 1R, Sta 20+00 to 25+00, full width",
    notes: "Aggregate base course, two 6-inch lifts. Nuclear density tests averaged 98.5% of max dry density.",
    checklist_answers: { 
      "material_submittals_approved_1" => "Yes",
      "weather_conditions_acceptable_2" => "Yes", 
      "equipment_clean_and_functional_3" => "Yes",
      "grade_and_alignment_checked_4" => "Yes",
      "safety_requirements_met_5" => "Yes",
      "photos_taken_6" => "Yes"
    }
  )
end

QaEntry.create!(
  report: report_3,
  qa_type: :nuclear_gauge,
  location: "Sta 22+50, centerline",
  result: :qa_pass,
  remarks: "Density: 98.8% of max dry density. Moisture: 5.2%. Target: 98% minimum."
)

QaEntry.create!(
  report: report_3,
  qa_type: :proof_roll,
  location: "Sta 20+00 to 25+00",
  result: :qa_pass,
  remarks: "No deflection or pumping observed under loaded dump truck. Subgrade adequate."
)

p152_bid_item = BidItem.find_by(project: project_2, code: "TWC-P-152")

report_4 = Report.create(
  user: tester,
  project: project_2,
  phase: phase_2,
  dir_number: "004",
  start_date: Date.today - 1.day,
  status: :revise,
  result: :fail,
  shift_start: "07:00",
  shift_end: "16:00",
  contractor: "Flatiron Construction Corp",
  
  temp_1: 55, weather_summary_1: "Clear", wind_1: "6mph W", precip_1: "0", visibility_1: "10+ miles",
  temp_2: 66, weather_summary_2: "Sunny", wind_2: "9mph SW", precip_2: "0", visibility_2: "10+ miles",
  temp_3: 64, weather_summary_3: "Partly Cloudy", wind_3: "11mph SW", precip_3: "0", visibility_3: "10+ miles",
  surface_conditions: "Excavated areas showed some soft spots requiring additional excavation and replacement with select material.",
  
  deficiency_status: :yes_deficiency,
  deficiency_desc: "Over-excavation encountered at Station 18+25 where soft subgrade material extended 18 inches below plan grade. Area approximately 200 square feet requires removal and replacement with compacted select fill. Contractor notified and corrective action plan submitted for approval.",
  
  safety_incident: :safety_na,
  traffic_control: :tc_yes,
  environmental: :env_yes,
  security: :sec_yes,
  air_ops_coordination: :air_yes,
  swppp_controls: :swppp_yes,
  phasing_compliance: :phase_yes,
  
  commentary: "Excavation and grading operations conducted along Taxiway Charlie from Station 15+00 to Station 22+00. Initial excavation performed to plan subgrade elevation using GPS-controlled excavators. Proof rolling conducted following initial excavation revealed soft spot at Station 18+25 requiring additional investigation. Probing indicated unsuitable material extending approximately 18 inches below plan grade over an area of approximately 200 square feet. Contractor halted operations in affected area pending approval of corrective action plan. Remainder of excavated area proof rolled satisfactorily with no deflection or pumping. Grade stakes set at 50-foot intervals and cross-slopes verified. Unsuitable material stockpiled in designated area for off-site disposal. Weather conditions favorable for earthwork operations.",
  
  additional_activities: "Coordinated with geotechnical engineer regarding unexpected soil conditions. Submitted corrective action plan for over-excavated area including removal limits, select fill specification, and compaction requirements. Arranged for additional testing to verify extent of unsuitable material.",
  
  additional_info: "Work in deficient area suspended pending approval of corrective measures. Excavation operations will continue in unaffected areas while awaiting geotechnical review and approval to proceed with remedial work."
)

CrewEntry.create!(
  report: report_4,
  contractor: "Flatiron Construction Corp",
  superintendent_count: 1,
  foreman_count: 2,
  operator_count: 4,
  laborer_count: 5,
  notes: "Excavation crew including excavator operators, dozer operator, grade checker, and laborers for stake setting and cleanup."
)

EquipmentEntry.create!(
  report: report_4,
  contractor: "Flatiron Construction Corp",
  make_model: "Caterpillar 320 Excavator with GPS",
  quantity: 2,
  hours: 8.0
)

EquipmentEntry.create!(
  report: report_4,
  contractor: "Flatiron Construction Corp",
  make_model: "Caterpillar D6 Dozer",
  quantity: 1,
  hours: 7.0
)

if p152_bid_item
  PlacedQuantity.create!(
    report: report_4,
    bid_item: p152_bid_item,
    quantity: 620.0,
    location: "Taxiway Charlie, Sta 15+00 to 22+00 (excluding deficient area)",
    notes: "Excavation to subgrade elevation. Soft spot at Sta 18+25 requires remedial work before proceeding.",
    checklist_answers: { 
      "material_submittals_approved_1" => "Yes",
      "weather_conditions_acceptable_2" => "Yes",
      "equipment_clean_and_functional_3" => "Yes",
      "grade_and_alignment_checked_4" => "No",
      "safety_requirements_met_5" => "Yes",
      "photos_taken_6" => "Yes"
    }
  )
end

QaEntry.create!(
  report: report_4,
  qa_type: :proof_roll,
  location: "Sta 18+25",
  result: :qa_fail,
  remarks: "Deflection and pumping observed indicating unsuitable subgrade. Additional excavation required."
)

puts "📊 Maestro: Creating finalized quantity history for Runway 1R..."

rw1r_focus_bid_items = {
  "RW1R-P-401" => BidItem.find_by(project: project_1, code: "RW1R-P-401"),
  "RW1R-P-501" => BidItem.find_by(project: project_1, code: "RW1R-P-501"),
  "RW1R-P-603" => BidItem.find_by(project: project_1, code: "RW1R-P-603"),
  "RW1R-P-620" => BidItem.find_by(project: project_1, code: "RW1R-P-620"),
  "RW1R-P-306" => BidItem.find_by(project: project_1, code: "RW1R-P-306")
}.compact

puts "📑 Maestro: Creating 10 Finalized Reports (Feb 2-6, 2026)..."

finalized_week_reports = [
  # Monday, Feb 2 - Report 1: Paving Operations
  {
    date: Date.new(2026, 2, 2),
    dir_number: "RW1R-Daily-050",
    shift: ["07:00", "15:30"],
    weather: {
      temp_1: 45, weather_summary_1: "Cloudy", wind_1: "5mph N", precip_1: "0", visibility_1: "10 miles",
      temp_2: 52, weather_summary_2: "Partly Cloudy", wind_2: "7mph NW", precip_2: "0", visibility_2: "10 miles",
      temp_3: 50, weather_summary_3: "Partial Sun", wind_3: "8mph NW", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Dry pavement, ambient temperature adequate for asphalt placement. Surface temperature 55°F at 0700.",
    commentary: "Paving operations continued on Runway 1R from Sta 50+00 to Sta 55+00. Crew began at 0730 by tacking the prepared surface with emulsified asphalt applied at 0.05 gal/SY. Tack coat was allowed to break for 30 minutes before paving commenced. First lift of P-401 asphalt surface course placed at 2.5-inch compacted thickness. Mix arrived at consistent 300-310°F from the plant. Caterpillar AP1000 paver maintained steady forward progress at 25 ft/min. Breakdown rolling with Bomag BW213 followed immediately behind the screed. Pneumatic and finish rolling completed the compaction operation. Nuclear density gauges confirmed readings of 95.8% to 97.2% of maximum theoretical density across four test locations. Longitudinal joints were properly pinched. No segregation, tearing, or mat defects observed. All transverse joints were constructed as full-depth butt joints with tack applied to the vertical face.",
    activities: "Pre-paving safety meeting held at 0700 covering traffic control plan and hot material handling procedures. Coordination with Airport Operations for Runway 1R closure window (0700-1600). Nuclear gauge calibration verified against reference block. Mix design JMF-2025-041 confirmed with plant operator. Three asphalt temperature checks on delivery trucks verified compliance (295°F, 308°F, 302°F).",
    additional_info: "Plant production rate approximately 250 tons/hour. Total tonnage placed today: 1,420 tons. Weather forecast shows clear conditions through Wednesday.",
    quantities: { "RW1R-P-401" => 850.0, "RW1R-P-603" => 250.0 },
    crew: { supt: 1, foreman: 1, operator: 4, laborer: 6, notes: "Full paving crew including paver operator, 2 roller operators, grade checker, and 6 laborers for material transfer, lute work, and joint construction." },
    equipment: [
      { name: "Caterpillar AP1000 Paver", qty: 1, hours: 7.5 },
      { name: "Bomag BW213 Roller", qty: 1, hours: 7.0 },
      { name: "Wirtgen W210 Cold Mill", qty: 1, hours: 3.0 }
    ],
    qa: [
      { type: :nuclear_gauge, location: "Sta 51+00, 12' left of CL", result: :qa_pass, remarks: "Density 96.5% of MTD. Target: 95% min. Moisture: 3.2%." },
      { type: :nuclear_gauge, location: "Sta 53+50, 8' right of CL", result: :qa_pass, remarks: "Density 97.2% of MTD. Excellent compaction." },
      { type: :asphalt_temp, location: "Truck #7, Sta 52+00", result: :qa_pass, remarks: "Mat temperature 305°F at laydown. Within 275-325°F spec range." }
    ],
    checklists: ["P-401", "P-603"]
  },

  # Monday, Feb 2 - Report 2: Electrical Work
  {
    date: Date.new(2026, 2, 2),
    dir_number: "RW1R-Daily-051",
    shift: ["07:00", "15:30"],
    weather: {
      temp_1: 46, weather_summary_1: "Cloudy", wind_1: "5mph N", precip_1: "0", visibility_1: "10 miles",
      temp_2: 53, weather_summary_2: "Partly Cloudy", wind_2: "6mph NW", precip_2: "0", visibility_2: "10 miles",
      temp_3: 51, weather_summary_3: "Partial Sun", wind_3: "7mph NW", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Trench areas dry. Conduit bedding material placed on firm subgrade.",
    commentary: "Electrical crew installed airfield lighting cable along the eastern runway edge from Sta 50+00 to Sta 60+00 (1,000 LF total). Work began with conduit inspection using a mandrel pull-through to verify no blockages or damage from prior earthwork operations. All conduits passed inspection. Cable pulling operations commenced at 0800 using a cable tugger with maximum pulling tension limited to 600 lbs per manufacturer specification. L-824 Type C, 5kV cable was installed in 2-inch Schedule 40 PVC conduit. Cable slack coils were placed at each light base location per detail on Sheet E-12. Light base cans were adjusted to final grade elevation using laser level (+/- 1/8 inch tolerance). Twelve base cans were set today. All conductor terminations were documented with mega-ohm readings to verify insulation integrity. Junction box covers installed and secured.",
    activities: "Verified conduit depth (minimum 24 inches below finished grade) at three random locations using probe rod. Confirmed light fixture submittals approved (Crouse-Hinds L-862E series). Coordinated with paving crew regarding conduit crossing locations to prevent damage during compaction.",
    additional_info: "Remaining cable pulling from Sta 60+00 to 70+00 scheduled for later this week. Transformer vault installation to begin next week.",
    quantities: { "RW1R-P-610" => 1000.0 },
    crew: { supt: 0, foreman: 1, operator: 2, laborer: 4, electrician: 3, notes: "Electrical sub-crew: 1 foreman, 3 licensed electricians, 2 equipment operators (cable tugger, skiploader), 4 laborers for trench work and base installation." },
    equipment: [
      { name: "JD 210 Skiploader", qty: 1, hours: 6.0 }
    ],
    qa: [
      { type: :compaction, location: "Trench backfill, Sta 55+00", result: :qa_pass, remarks: "Trench backfill compaction 96% of max dry density per ASTM D1557." }
    ],
    checklists: ["P-610"]
  },

  # Tuesday, Feb 3 - Report 1: Paving Operations
  {
    date: Date.new(2026, 2, 3),
    dir_number: "RW1R-Daily-052",
    shift: ["07:00", "16:00"],
    weather: {
      temp_1: 42, weather_summary_1: "Clear", wind_1: "10mph NW", precip_1: "0", visibility_1: "10 miles",
      temp_2: 48, weather_summary_2: "Sunny", wind_2: "11mph NW", precip_2: "0", visibility_2: "10+ miles",
      temp_3: 50, weather_summary_3: "Sunny", wind_3: "12mph NW", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Dry pavement from yesterday's first lift. Previous lift surface swept clean. Tack coat applied and broken.",
    commentary: "Completed second lift of P-401 asphalt surface course on Runway 1R, Sta 50+00 to 55+00. Joint density testing was a primary focus today with three additional nuclear gauge tests taken at longitudinal joint locations. All joint densities exceeded 93% of mat density, meeting P-401-4.12 requirements. Longitudinal joints were pinched properly by the breakdown roller operating in vibratory mode. Mat texture appeared uniform with no segregation, tearing, or surface irregularities. Final surface elevation checked against plan grade at 25-foot intervals using string line and digital level — all readings within 1/4-inch tolerance. Paving rate maintained at 200 tons/hour. Total tonnage placed: 1,310 tons. Completed section from Sta 50+00 to 55+00 now has both lifts at full design thickness of 5.0 inches compacted.",
    activities: "Pre-paving meeting at 0645 reviewed joint construction techniques and rolling pattern. Verified tack coat break on yesterday's lift. Temperature monitoring of asphalt delivery — all 18 trucks within specification range. Coordinated with QC lab for next-day core sampling schedule.",
    additional_info: "Cores to be taken from today's section Wednesday morning for verification testing. Plant produced 1,350 tons gross with 40 tons wasted due to temperature drop on hold truck during mid-morning fuel stop.",
    quantities: { "RW1R-P-401" => 820.0, "RW1R-P-603" => 200.0 },
    crew: { supt: 1, foreman: 1, operator: 5, laborer: 6, notes: "Main paving crew: paver operator, 3 roller operators (breakdown, intermediate, finish), motor grader operator for grade check, 6 laborers." },
    equipment: [
      { name: "Caterpillar AP1000 Paver", qty: 1, hours: 8.0 },
      { name: "Bomag BW213 Roller", qty: 1, hours: 7.5 },
      { name: "Hamm HD120 Roller", qty: 1, hours: 7.5 }
    ],
    qa: [
      { type: :nuclear_gauge, location: "Sta 51+50, longitudinal joint", result: :qa_pass, remarks: "Joint density 94.1% of mat density. Spec requires 93% min." },
      { type: :nuclear_gauge, location: "Sta 53+00, 15' left of CL", result: :qa_pass, remarks: "Density 96.8% of MTD. Second lift compaction excellent." },
      { type: :nuclear_gauge, location: "Sta 54+25, 10' right of CL", result: :qa_pass, remarks: "Density 95.9% of MTD." },
      { type: :asphalt_temp, location: "Truck #12, Sta 52+50", result: :qa_pass, remarks: "Mat temperature 298°F at laydown. Ambient 48°F." }
    ],
    checklists: ["P-401", "P-603"]
  },

  # Tuesday, Feb 3 - Report 2: Drainage Work
  {
    date: Date.new(2026, 2, 3),
    dir_number: "RW1R-Daily-053",
    shift: ["07:30", "15:30"],
    weather: {
      temp_1: 43, weather_summary_1: "Clear", wind_1: "8mph NW", precip_1: "0", visibility_1: "10 miles",
      temp_2: 49, weather_summary_2: "Sunny", wind_2: "9mph NW", precip_2: "0", visibility_2: "10+ miles",
      temp_3: 51, weather_summary_3: "Sunny", wind_3: "10mph NW", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Trench excavation in dry native soil. Subgrade firm and stable.",
    commentary: "Drainage crew installed 200 LF of 6-inch perforated HDPE underdrain piping along the runway shoulder from Sta 52+00 to Sta 54+00. Trench excavated to 36-inch depth using Hitachi excavator with 18-inch bucket. Geotextile filter fabric (Mirafi 140N, per approved submittal) placed in trench before pipe installation. Pipe bedded on 4-inch layer of AASHTO #57 stone. Porous aggregate backfill (P-209 specification) placed in 6-inch lifts and hand-compacted around pipe. Backfill brought to within 12 inches of final grade. Pipe invert elevations verified at each end and at 50-foot intervals — all within 0.02-foot tolerance of plan. Positive drainage gradient of 0.5% confirmed. Filter fabric overlap of 12 inches minimum maintained at all seams per P-209 detail.",
    activities: "Verified pipe invert elevations using automatic level and benchmark. Inspected filter fabric overlap at all joints (min 12 inches required, actual 14-16 inches). Confirmed aggregate gradation certificate on file for #57 stone backfill. Photographed typical trench section before backfill.",
    additional_info: "Underdrain connection to outfall structure at Sta 55+50 to be completed Thursday. Remaining 150 LF of underdrain along west shoulder scheduled for next week.",
    quantities: { "RW1R-P-209" => 150.0 },
    crew: { supt: 0, foreman: 1, operator: 2, laborer: 4, notes: "Drainage crew: foreman, excavator operator, loader operator, 4 laborers for pipe handling, fabric placement, and hand compaction." },
    equipment: [
      { name: "Hitachi ZX350 Excavator", qty: 1, hours: 7.0 },
      { name: "Volvo L120 Loader", qty: 1, hours: 5.0 }
    ],
    qa: [
      { type: :compaction, location: "Trench backfill, Sta 53+00", result: :qa_pass, remarks: "Backfill compaction 97.5% of max dry density. Moisture 4.8%." },
      { type: :proof_roll, location: "Sta 52+00 to 54+00, shoulder area", result: :qa_pass, remarks: "No deflection observed over completed underdrain trench. Backfill adequate." }
    ],
    checklists: ["P-209"]
  },

  # Wednesday, Feb 4 - Report 1: Survey & Layout Day
  {
    date: Date.new(2026, 2, 4),
    dir_number: "RW1R-Daily-054",
    shift: ["07:00", "15:30"],
    weather: {
      temp_1: 48, weather_summary_1: "Overcast", wind_1: "5mph SW", precip_1: "Trace", visibility_1: "8 miles",
      temp_2: 51, weather_summary_2: "Cloudy", wind_2: "6mph SW", precip_2: "0", visibility_2: "8 miles",
      temp_3: 54, weather_summary_3: "Cloudy", wind_3: "6mph SW", precip_3: "0", visibility_3: "9 miles"
    },
    surface_conditions: "Damp pavement surface from overnight moisture. Cleared by mid-morning.",
    commentary: "No asphalt paving operations today due to early morning trace precipitation and surface moisture. Decision made at 0630 pre-work meeting to hold paving until surface was confirmed dry. Crew redirected to survey layout, site housekeeping, and preparation work for upcoming marking operations. Survey crew established temporary centerline control points on the newly paved section (Sta 50+00 to 55+00) using total station referenced to project control network. Centerline paint marks placed at 100-foot intervals. Edge of pavement offsets verified against plan dimensions. Preparation for runway marking included review of marking layout plan (Sheet M-1) and verification of paint/bead equipment calibration. Site housekeeping activities included removal of construction debris from paved shoulders, cleaning of drainage inlets, and organization of material staging areas. Equipment maintenance performed on paver and rollers during the stand-down period.",
    activities: "Survey established 6 control points along Sta 50-55 section. Paver screed plates inspected and adjusted. Roller drum surfaces checked for flat spots. Traffic control devices inspected and replaced as needed. Fuel and fluid levels topped off on all equipment.",
    additional_info: "Weather forecast shows clearing tonight with dry conditions expected Thursday and Friday. Paving to resume Thursday at Sta 55+00.",
    quantities: {},
    crew: { supt: 1, foreman: 1, operator: 2, laborer: 4, survey: 2, notes: "Reduced crew for survey and cleanup: superintendent, foreman, 2 operators (equipment maintenance), 2 survey technicians, 4 laborers for site housekeeping." },
    equipment: [
      { name: "JD 210 Skiploader", qty: 1, hours: 4.0 }
    ],
    qa: [],
    checklists: []
  },

  # Wednesday, Feb 4 - Report 2: Earthwork/Shoulders
  {
    date: Date.new(2026, 2, 4),
    dir_number: "RW1R-Daily-055",
    shift: ["07:00", "15:00"],
    weather: {
      temp_1: 48, weather_summary_1: "Overcast", wind_1: "4mph SW", precip_1: "Trace", visibility_1: "8 miles",
      temp_2: 52, weather_summary_2: "Cloudy", wind_2: "5mph S", precip_2: "0", visibility_2: "8 miles",
      temp_3: 53, weather_summary_3: "Cloudy", wind_3: "5mph S", precip_3: "Tr", visibility_3: "9 miles"
    },
    surface_conditions: "Shoulder subgrade slightly moist from overnight trace precip. Moisture content tested at 7.2% — within 2% of optimum, acceptable for compaction.",
    commentary: "Earthwork crew graded the Runway Safety Area (RSA) shoulders from Sta 50+00 to Sta 52+00 (400 LF, both sides). Operations began at 0730 after moisture content testing confirmed acceptable conditions. Motor grader shaped shoulder material to design cross-slope of 2.5% away from pavement edge. Fill material placed in 8-inch loose lifts (6-inch compacted). Each lift compacted with vibratory smooth-drum roller making 4 passes in vibratory mode followed by 2 static passes. Nuclear density testing performed at 200-foot intervals on each lift — all readings exceeded 95% of maximum dry density per ASTM D1557 (modified Proctor). Final shoulder elevation matched pavement edge within 1/4 inch as verified by straightedge. Topsoil placed on completed shoulders at 4-inch depth and track-rolled to establish firm seedbed. Positive drainage verified away from runway pavement using a 4-foot level.",
    activities: "Verified shoulder grades against plan cross-sections at Sta 50+00, 51+00, and 52+00. Confirmed compaction of underlying fill using proof roll (loaded tandem truck, no deflection). Coordinated with erosion control crew for temporary seed/mulch application on completed shoulders.",
    additional_info: "Shoulder grading to continue eastward from Sta 52+00 as paving progresses ahead. Seeding and mulching crew scheduled for Friday on completed shoulder sections.",
    quantities: { "RW1R-P-152" => 400.0 },
    crew: { supt: 0, foreman: 1, operator: 3, laborer: 3, notes: "Earthwork crew: foreman, dozer operator, motor grader operator, roller operator, 3 laborers for grade checking and hand work." },
    equipment: [
      { name: "Caterpillar D6 Dozer", qty: 1, hours: 7.0 },
      { name: "Caterpillar 140M Motor Grader", qty: 1, hours: 6.5 }
    ],
    qa: [
      { type: :nuclear_gauge, location: "Sta 50+50, east shoulder, 2nd lift", result: :qa_pass, remarks: "Density 96.1% of MDD. Moisture 6.8%, within optimum range." },
      { type: :nuclear_gauge, location: "Sta 51+50, west shoulder, final lift", result: :qa_pass, remarks: "Density 95.4% of MDD. Moisture 7.0%." },
      { type: :proof_roll, location: "Sta 50+00 to 52+00, both shoulders", result: :qa_pass, remarks: "No deflection under loaded tandem axle truck. Subgrade adequate." }
    ],
    checklists: ["P-152"]
  },

  # Thursday, Feb 5 - Report 1: Paving Operations Resumed
  {
    date: Date.new(2026, 2, 5),
    dir_number: "RW1R-Daily-056",
    shift: ["06:30", "16:30"],
    weather: {
      temp_1: 40, weather_summary_1: "Fog", wind_1: "Calm", precip_1: "0", visibility_1: "1/4 mile",
      temp_2: 52, weather_summary_2: "Clearing", wind_2: "3mph NE", precip_2: "0", visibility_2: "5 miles",
      temp_3: 58, weather_summary_3: "Sunny", wind_3: "5mph NE", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Surface initially damp from fog condensation. Confirmed dry by 0845 using paper towel blotter test. Surface temperature 52°F at 0900, above 45°F minimum.",
    notable_weather: "Dense fog until 0845, visibility below 1/4 mile. Operations delayed 2 hours.",
    commentary: "Fog delayed paving start until 0900 per P-401 specification requirement for dry surface conditions. Once fog cleared and surface was confirmed dry, asphalt paving resumed at Sta 55+00 heading east. First lift of P-401 surface course placed from Sta 55+00 to Sta 58+00 (3,000 LF = 900 SY at 27-foot width). Mix temperature was elevated 10°F at the plant (target 315°F) to compensate for cooler ambient temperatures and longer haul time due to fog-related traffic delays on access road. Despite the late start, crew extended shift to 1630 to maximize production. Compaction results were excellent — all eight nuclear gauge readings ranged from 96.0% to 98.1% of maximum theoretical density. No mat defects, segregation, or roller marks observed. Transverse construction joint at Sta 55+00 was cut back 6 inches to sound material and tacked before paving against it. Longitudinal joint at lane line constructed with proper overlap and pinching technique.",
    activities: "Fog hold from 0630-0900. Plant inspection conducted during hold — verified mix design, calibrations, and aggregate moisture sensors. Density testing frequency increased to every 300 LF due to cooler-than-normal ambient conditions. Contractor provided additional water for roller drums (steel drum rollers). Reviewed haul route condition with contractor after fog cleared.",
    additional_info: "Extended shift resulted in 2,100 tons placed despite 2-hour delay. Plant operated smoothly with no breakdowns. Crew to return at 0630 Friday for final paving push to Sta 60+00.",
    quantities: { "RW1R-P-401" => 900.0, "RW1R-P-603" => 280.0 },
    crew: { supt: 1, foreman: 1, operator: 6, laborer: 7, notes: "Extended shift crew: superintendent, foreman, paver operator, 3 roller operators, grade checker, water truck operator, 7 laborers. Additional laborers added for extended shift coverage." },
    equipment: [
      { name: "Caterpillar AP1000 Paver", qty: 1, hours: 7.0 },
      { name: "Bomag BW213 Roller", qty: 1, hours: 7.0 },
      { name: "Hamm HD120 Roller", qty: 1, hours: 7.0 },
      { name: "Wirtgen W210 Cold Mill", qty: 1, hours: 2.0 }
    ],
    qa: [
      { type: :nuclear_gauge, location: "Sta 55+50, 10' left of CL", result: :qa_pass, remarks: "Density 97.1% of MTD at construction joint area. Excellent." },
      { type: :nuclear_gauge, location: "Sta 56+50, 12' right of CL", result: :qa_pass, remarks: "Density 96.4% of MTD. Moisture 3.0%." },
      { type: :nuclear_gauge, location: "Sta 57+50, centerline", result: :qa_pass, remarks: "Density 98.1% of MTD. Highest reading of the day." },
      { type: :asphalt_temp, location: "Truck #3, Sta 55+25", result: :qa_pass, remarks: "Mat temperature 312°F at laydown. Elevated per cold weather protocol." },
      { type: :asphalt_temp, location: "Truck #15, Sta 57+75", result: :qa_pass, remarks: "Mat temperature 308°F at laydown. Within specification." }
    ],
    checklists: ["P-401", "P-603"]
  },

  # Thursday, Feb 5 - Report 2: Marking
  {
    date: Date.new(2026, 2, 5),
    dir_number: "RW1R-Daily-057",
    shift: ["10:00", "16:00"],
    weather: {
      temp_1: 52, weather_summary_1: "Clearing", wind_1: "3mph NE", precip_1: "0", visibility_1: "5 miles",
      temp_2: 56, weather_summary_2: "Partly Sunny", wind_2: "4mph NE", precip_2: "0", visibility_2: "8 miles",
      temp_3: 60, weather_summary_3: "Sunny", wind_3: "6mph NE", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Paved surface clean and dry. Surface temperature 58°F at start, above 50°F minimum for paint application.",
    commentary: "Marking crew applied temporary runway markings on the completed paving section from Sta 50+00 to Sta 55+00 (1,500 LF of centerline plus edge markings). Late start due to morning fog — surface needed to be confirmed dry and above minimum temperature. Temporary white centerline stripe applied at 6-inch width using truck-mounted airless spray unit. Edge markings applied at 12-inch width on both sides. Type III glass beads applied at 6 lbs/gallon to wet paint per P-620 specification. Film thickness measurements taken at three locations averaged 18 mils wet (specification: 15-20 mils). Retroreflectivity readings taken on dried markings after 1-hour cure ranged from 250 to 310 mcd/m²/lux, exceeding the 200 mcd minimum. Layout was verified against marking plan (Sheet M-1) with centerline offset measured at 6 locations — all within 1-inch tolerance. Paint adhesion confirmed adequate via thumb test on dried marking.",
    activities: "Layout verification using total station referenced to runway centerline control points. Flow rate calibration check on paint truck dispenser. Glass bead hopper checked for proper drop rate. Pre-application surface cleaning with power broom on truck-mounted sweeper.",
    additional_info: "Permanent markings to be applied after final lift of asphalt is placed on this section. Current markings are temporary for operational safety during construction phasing.",
    quantities: { "RW1R-P-620" => 1500.0 },
    crew: { supt: 0, foreman: 1, operator: 2, laborer: 2, notes: "Striping crew: foreman, paint truck operator, layout technician, 2 laborers for traffic control and bead equipment." },
    equipment: [],
    qa: [
      { type: :compaction, location: "Sta 52+00 centerline marking", result: :qa_pass, remarks: "Film thickness 18 mils wet. Retroreflectivity 285 mcd/m²/lux after cure. Both meet P-620 specs." }
    ],
    checklists: ["P-620"]
  },

  # Friday, Feb 6 - Report 1: Paving Operations
  {
    date: Date.new(2026, 2, 6),
    dir_number: "RW1R-Daily-058",
    shift: ["07:00", "15:00"],
    weather: {
      temp_1: 50, weather_summary_1: "Clear", wind_1: "8mph E", precip_1: "0", visibility_1: "10 miles",
      temp_2: 58, weather_summary_2: "Sunny", wind_2: "9mph E", precip_2: "0", visibility_2: "10+ miles",
      temp_3: 62, weather_summary_3: "Sunny", wind_3: "10mph E", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Dry pavement, excellent conditions for asphalt placement. Surface temperature 56°F at 0700.",
    commentary: "Completed paving for the week, placing P-401 surface course first lift from Sta 58+00 to Sta 60+00 (750 SY). Transverse construction joint at Sta 60+00 was constructed as a full-depth butt joint with vertical face for continuation next week. The Sta 58+00 transverse joint from yesterday's pour was cut back 6 inches with a diamond-blade saw and tacked before paving against it. All equipment cleaned and parked in staging area after production ceased at 1400. Final nuclear gauge readings at four test locations ranged from 95.5% to 97.3% of maximum theoretical density. End-of-week quantity reconciliation performed with contractor — cumulative P-401 quantities for the week total 3,320 SY (Sta 50+00 to 60+00, first lift). Plant tickets collected and verified against delivered tonnage. No deficiencies, safety incidents, or environmental issues observed. All traffic control maintained through weekend per phasing plan.",
    activities: "End-of-week closeout meeting held at 1430 covering: weekly production summary (3,320 SY), QA test result compilation, schedule update discussion, and next week's paving plan review (second lift Sta 55-60, first lift Sta 60-65). Joint inspection on Sta 60+00 construction joint — clean vertical face confirmed. Quantity reconciliation: 3,320 SY P-401 placed, 950 gal P-603 tack coat applied.",
    additional_info: "Weekly production exceeded target of 3,000 SY despite Wednesday weather day and Thursday fog delay. Plant to remain on standby for Monday 0700 start. Contractor confirmed adequate aggregate and liquid asphalt supply for next week's production.",
    quantities: { "RW1R-P-401" => 750.0, "RW1R-P-603" => 220.0 },
    crew: { supt: 1, foreman: 1, operator: 5, laborer: 6, notes: "Standard paving crew for Friday finish. Early release at 1500 after cleanup and equipment parking." },
    equipment: [
      { name: "Caterpillar AP1000 Paver", qty: 1, hours: 6.0 },
      { name: "Bomag BW213 Roller", qty: 1, hours: 5.5 }
    ],
    qa: [
      { type: :nuclear_gauge, location: "Sta 58+50, 10' left of CL", result: :qa_pass, remarks: "Density 96.2% of MTD. Consistent with week's results." },
      { type: :nuclear_gauge, location: "Sta 59+50, 15' right of CL", result: :qa_pass, remarks: "Density 97.3% of MTD." },
      { type: :asphalt_temp, location: "Truck #8, Sta 59+00", result: :qa_pass, remarks: "Mat temperature 302°F at laydown. Within specification." }
    ],
    checklists: ["P-401", "P-603"]
  },

  # Friday, Feb 6 - Report 2: Electrical & Site Finish
  {
    date: Date.new(2026, 2, 6),
    dir_number: "RW1R-Daily-059",
    shift: ["07:30", "14:00"],
    weather: {
      temp_1: 52, weather_summary_1: "Clear", wind_1: "7mph E", precip_1: "0", visibility_1: "10 miles",
      temp_2: 60, weather_summary_2: "Sunny", wind_2: "8mph E", precip_2: "0", visibility_2: "10+ miles",
      temp_3: 64, weather_summary_3: "Sunny", wind_3: "9mph E", precip_3: "0", visibility_3: "10 miles"
    },
    surface_conditions: "Trench areas dry and firm. Previously compacted backfill in good condition.",
    commentary: "Electrical crew completed conduit runs and cable installation from Sta 55+00 to Sta 60+00 (800 LF additional). Work included pulling L-824 5kV cable through previously installed 2-inch PVC conduit, setting 8 additional light base cans to final grade, and completing all conductor terminations in this section. Trench backfill for the final 200 LF section was compacted in 6-inch lifts with hand-operated plate compactor and verified with nuclear density gauge. Mega-ohm readings on all conductors exceeded 100 MΩ, confirming insulation integrity. As-built survey data collected for conduit routing (horizontal and vertical positions) using total station. All junction box covers secured and base cans capped for protection during ongoing paving operations. Site cleaned up for the weekend — construction debris removed, material staging areas organized, and temporary barriers repositioned per weekend traffic control plan. SWPPP inspection performed with no deficiencies noted; all BMPs in place and functioning.",
    activities: "Trench compaction testing at two locations (both passed). As-built survey of conduit locations for record drawings. SWPPP weekly inspection. Weekend traffic control setup verification. Tool and equipment inventory for weekly report.",
    additional_info: "Electrical work in this section 85% complete. Remaining: final connections to transformer vault and functional testing (scheduled for Week 3). Total cable installed to date: 1,800 LF of 5kV L-824.",
    quantities: { "RW1R-P-610" => 800.0, "RW1R-P-152" => 100.0 },
    crew: { supt: 0, foreman: 1, operator: 2, laborer: 3, electrician: 2, notes: "Electrical crew plus general laborers for site cleanup. Early release at 1400 for weekend." },
    equipment: [
      { name: "JD 210 Skiploader", qty: 1, hours: 5.0 }
    ],
    qa: [
      { type: :compaction, location: "Trench backfill, Sta 58+00", result: :qa_pass, remarks: "Backfill compaction 97.2% of max dry density. Meets 95% minimum." },
      { type: :compaction, location: "Trench backfill, Sta 59+50", result: :qa_pass, remarks: "Backfill compaction 96.8% of max dry density." }
    ],
    checklists: ["P-610"]
  }
]

finalized_week_reports.each do |data|
  rep = Report.create!(
    user: admin,
    project: project_1,
    phase: finalized_phase,
    dir_number: data[:dir_number],
    start_date: data[:date],
    status: :finalize,
    result: :pass,
    shift_start: data[:shift][0],
    shift_end: data[:shift][1],
    contractor: "Granite Construction Company",

    # Weather (all three observation periods)
    temp_1: data[:weather][:temp_1],
    weather_summary_1: data[:weather][:weather_summary_1],
    wind_1: data[:weather][:wind_1],
    precip_1: data[:weather][:precip_1],
    visibility_1: data[:weather][:visibility_1],
    temp_2: data[:weather][:temp_2],
    weather_summary_2: data[:weather][:weather_summary_2],
    wind_2: data[:weather][:wind_2],
    precip_2: data[:weather][:precip_2],
    visibility_2: data[:weather][:visibility_2],
    temp_3: data[:weather][:temp_3],
    weather_summary_3: data[:weather][:weather_summary_3],
    wind_3: data[:weather][:wind_3],
    precip_3: data[:weather][:precip_3],
    visibility_3: data[:weather][:visibility_3],

    surface_conditions: data[:surface_conditions] || "Dry, acceptable conditions.",
    notable_weather_events: data[:notable_weather],

    # Compliance defaults
    deficiency_status: :no_deficiency,
    safety_incident: :safety_no,
    traffic_control: :tc_yes,
    environmental: :env_yes,
    security: :sec_yes,
    air_ops_coordination: :air_yes,
    swppp_controls: :swppp_yes,
    phasing_compliance: :phase_yes,

    commentary: data[:commentary],
    additional_activities: data[:activities],
    additional_info: data[:additional_info] || "Finalized seed report for Feb 2-6, 2026 simulation.",

    # Mark as approved and authorized
    approved_by_id: admin.id,
    approved_at: data[:date].to_datetime + 17.hours,
    authorized_by: admin,
    authorized_date: data[:date].to_datetime + 18.hours
  )

  # Crew
  CrewEntry.create!(
    report: rep,
    contractor: "Granite Construction Company",
    superintendent_count: data[:crew][:supt] || 0,
    foreman_count: data[:crew][:foreman] || 0,
    operator_count: data[:crew][:operator] || 0,
    laborer_count: data[:crew][:laborer] || 0,
    electrician_count: data[:crew][:electrician] || 0,
    survey_count: data[:crew][:survey] || 0,
    notes: data[:crew][:notes]
  )

  # Equipment (now with individual qty and hours)
  data[:equipment].each do |eq|
    EquipmentEntry.create!(
      report: rep,
      contractor: "Granite Construction Company",
      make_model: eq[:name],
      quantity: eq[:qty] || 1,
      hours: eq[:hours] || 8.0,
      remarks: "Operated during #{data[:shift][0]}-#{data[:shift][1]} shift."
    )
  end

  # Placed Quantities with detailed checklist answers
  data[:quantities].each do |code, qty|
    bid_item = BidItem.find_by(project: project_1, code: code)
    next unless bid_item

    spec_code = code.sub("RW1R-", "")

    # Build meaningful checklist answers based on spec type
    answers = case spec_code
    when "P-401"
      {
        "mix_design_id_1" => "JMF-2025-041",
        "lot__2" => rand(10..25),
        "lift_thickness_per_plan_3" => 2.5,
        "is_the_surface_dry_and_above_minimum_temperature_per_401_4_1_table_4_4" => "Yes",
        "was_the_surface_properly_cleaned_prior_to_applying_tack_coat_401_4_11_5" => "Yes",
        "are_haul_trucks_clean_401_4_4_6" => "Yes",
        "were_approved_release_agents_used_on_all_equipment_401_4_4_7" => "Yes",
        "were_qc_personnel_onsite_to_monitor_production_using_nuclear_density_gauges_401_4_7_8" => "Yes",
        "were_edges_of_existing_pavement_sawcut_in_accordance_with_401_4_12_p_4_9" => "Yes",
        "are_the_minimum_lane_width_requirements_met_per_plan_10" => "Yes",
        "were_longitudinal_and_transverse_joints_offset_11" => "Yes",
        "did_any_segment_of_paving_exhibit_segregation_12" => "No",
        "was_the_rolling_plan_implemented_13" => "Yes",
        "was_rolling_equipment_sufficiently_furnished_14" => "Yes",
        "did_the_contractor_deviate_from_the_approved_paving_plan_20" => "No"
      }
    when "P-603"
      {
        "material_submittals_approved_1" => "Yes",
        "weather_conditions_acceptable_2" => "Yes",
        "equipment_clean_and_functional_3" => "Yes",
        "grade_and_alignment_checked_4" => "Yes",
        "safety_requirements_met_5" => "Yes",
        "photos_taken_6" => "Yes"
      }
    when "P-620"
      {
        "surface_clean_and_dry_1" => "Yes",
        "layout_approved_2" => "Yes",
        "paint_type_color_verified_3" => "Yes",
        "film_thickness_mils_4" => 18,
        "glass_beads_applied_5" => "Yes",
        "bead_application_rate_lbs_gal_6" => 6.0,
        "drying_time_observed_minutes_7" => 45,
        "retroreflectivity_reading_8" => 285,
        "photos_taken_9" => "Yes"
      }
    when "P-610"
      {
        "material_submittals_approved_1" => "Yes",
        "weather_conditions_acceptable_2" => "Yes",
        "equipment_clean_and_functional_3" => "Yes",
        "grade_and_alignment_checked_4" => "Yes",
        "safety_requirements_met_5" => "Yes",
        "photos_taken_6" => "Yes"
      }
    when "P-152"
      {
        "material_submittals_approved_1" => "Yes",
        "weather_conditions_acceptable_2" => "Yes",
        "equipment_clean_and_functional_3" => "Yes",
        "grade_and_alignment_checked_4" => "Yes",
        "safety_requirements_met_5" => "Yes",
        "photos_taken_6" => "Yes"
      }
    when "P-209"
      {
        "material_submittals_approved_1" => "Yes",
        "weather_conditions_acceptable_2" => "Yes",
        "equipment_clean_and_functional_3" => "Yes",
        "grade_and_alignment_checked_4" => "Yes",
        "safety_requirements_met_5" => "Yes",
        "photos_taken_6" => "Yes"
      }
    else
      { "photos_taken_1" => "Yes" }
    end

    PlacedQuantity.create!(
      report: rep,
      bid_item: bid_item,
      quantity: qty,
      location: "Runway 1R, Sta 50+00 to 60+00 corridor",
      notes: "#{spec_code} daily production for #{data[:date].strftime('%m/%d/%Y')}. DIR #{data[:dir_number]}.",
      checklist_answers: answers
    )
  end

  # QA Entries
  (data[:qa] || []).each do |qa|
    QaEntry.create!(
      report: rep,
      qa_type: qa[:type],
      location: qa[:location],
      result: qa[:result],
      remarks: qa[:remarks]
    )
  end

  # Checklist Entries (completed spec checklists)
  (data[:checklists] || []).each do |spec_code|
    spec = SpecItem.find_by(code: spec_code)
    next unless spec

    # Build "all Yes" answers for completed checklist
    answers = {}
    if spec.checklist_questions.is_a?(Array)
      spec.checklist_questions.each_with_index do |q, idx|
        key = q["id"] || "question_#{idx + 1}"
        kind = q["kind"] || "radio"
        answers[key] = case kind
                        when "radio" then "Yes"
                        when "number" then rand(1..100)
                        when "text" then "Verified and acceptable"
                        when "textarea" then "All items inspected and found compliant with specification requirements."
                        else "Yes"
                        end
      end
    end

    ChecklistEntry.create!(
      report: rep,
      spec_item: spec,
      checklist_answers: answers
    )
  end

  puts "   ✓ Created report #{data[:dir_number]} (#{data[:date]}) with #{data[:quantities].size} quantities, #{(data[:qa] || []).size} QA entries, #{(data[:checklists] || []).size} checklists"
end

report_dates = (15.downto(1).map { |days_ago| Date.today - days_ago.days })

report_dates.each_with_index do |report_date, idx|
  final_report = Report.create(
    user: (idx.even? ? admin : tester),
    project: project_1,
    phase: finalized_phase,
    dir_number: format("F%03d", idx + 1),
    start_date: report_date,
    status: :finalize,
    result: :pass,
    shift_start: "07:00",
    shift_end: "15:30",
    contractor: "Granite Construction Company",
    commentary: "Finalized production report for Runway 1R Rehabilitation quantity tracking.",
    additional_activities: "Compiled and verified daily quantity measurements for bid-item progress tracking.",
    additional_info: "Used for data viewer population and historical quantity analysis."
  )

  quantity_map = {
    "RW1R-P-401" => 420 + (idx * 12),
    "RW1R-P-501" => 185 + (idx * 8),
    "RW1R-P-603" => 560 + (idx * 15),
    "RW1R-P-620" => 310 + (idx * 10),
    "RW1R-P-306" => 240 + (idx * 9)
  }

  rw1r_focus_bid_items.each do |code, bid_item|
    PlacedQuantity.create!(
      report: final_report,
      bid_item: bid_item,
      quantity: quantity_map[code],
      location: "Runway 1R Rehab - Work Segment #{idx + 1}",
      notes: "Finalized quantity entry for #{code} on #{report_date}.",
      checklist_answers: {}
    )
  end
end

puts "✅ Maestro: Seeding Complete!"
puts "   Users:"
puts "     - admin@cms.com / cloudattack"
puts "     - tester@cms.com / cloudattack"
puts "   Projects: 2 (#{project_1.name}, #{project_2.name})"
puts "   Spec Divisions: #{faa_specs.keys.count} (all represented in both projects)"
puts "   Bid Items: #{BidItem.count} total"
puts "   Approved Equipment: #{ApprovedEquipment.count} items across projects"
puts "   Reports: #{Report.count} total"
puts "     - 10 finalized reports for Feb 2-6, 2026 (Runway 1R) with full data"
puts "     - 15 finalized quantity-history reports"
puts "     - 4 sample reports (various statuses)"
puts "   QA Entries: #{QaEntry.count} total"
puts "   Checklist Entries: #{ChecklistEntry.count} total"
puts "   Placed Quantities: #{PlacedQuantity.count} total"
