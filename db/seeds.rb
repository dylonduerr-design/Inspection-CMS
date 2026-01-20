# db/seeds.rb

puts "🌱 Maestro: Cleaning old data..."
ApprovedEquipment.destroy_all
ChecklistEntry.destroy_all
PlacedQuantity.destroy_all
QaEntry.destroy_all
CrewEntry.destroy_all
EquipmentEntry.destroy_all
ReportAttachment.destroy_all
Report.destroy_all
AuditLog.destroy_all
BidItem.destroy_all
SpecItem.destroy_all
Project.destroy_all
Phase.destroy_all
User.destroy_all

puts "👤 Maestro: Creating Users..."
admin = User.create!(
  email: "admin@cms.com",
  password: "cloudattack",
  password_confirmation: "cloudattack",
  role: :qc
)

tester = User.create!(
  email: "tester@cms.com",
  password: "cloudattack",
  password_confirmation: "cloudattack",
  role: :inspector
)

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
  build_question("Material submittals approved?"),
  build_question("Tack coat applied and broken?"),
  build_question("Surface temperature (°F)", kind: "number", placeholder: "Enter temperature", 
                 validation: { min: 50, max: 200 }),
  build_question("Mat temperature at laydown (°F)", kind: "number", placeholder: "Enter temperature",
                 validation: { min: 250, max: 350 }),
  build_question("Compacted lift thickness (inches)", kind: "number", placeholder: "Enter thickness",
                 validation: { min: 1, max: 6, step: 0.25 }),
  build_question("Rolling pattern observed?"),
  build_question("Joint construction acceptable?"),
  build_question("Core sample location", kind: "text", placeholder: "Station + Offset"),
  build_question("Deficiencies noted", kind: "textarea", placeholder: "Describe any deficiencies observed..."),
  build_question("Photos taken?")
]

# P-403 Asphalt Mix Pavement [Base/Leveling/Surface] - Comprehensive checklist
p403_questions = [
  build_question("Mix Design ID", kind: "text", placeholder: "Enter mix design ID"),
  build_question("Cement Content (%)", kind: "text", placeholder: "Enter cement content percentage"),
  build_question("% Passing No.200 Sieve", kind: "text", placeholder: "Enter percentage passing No.200 sieve"),
  build_question("Flat/Elongated Particles (%)", kind: "text", placeholder: "Enter flat/elongated particles percentage"),
  build_question("Wear (ASTM C131) (%)", kind: "text", placeholder: "Enter wear test percentage"),
  build_question("Curing Method", kind: "select", options: ["Air Dry", "Moist Cure", "Membrane Cure", "Steam Cure", "Other"]),
  build_question("Lot ID", kind: "text", placeholder: "Enter lot ID"),
  build_question("Sublot Area (Cu YDS)", kind: "number", placeholder: "Enter sublot area in cubic yards", validation: { min: 0 }),
  build_question("Density Tests per Sublot", kind: "number", placeholder: "Enter number of density tests per sublot", validation: { min: 0 }),
  build_question("In-Place Density (%)", kind: "text", placeholder: "Enter in-place density percentage"),
  build_question("Thickness Cores per Sublot", kind: "number", placeholder: "Enter cores per sublot", validation: { min: 0, step: 0.1 }),
  build_question("Average Lot Thickness (inches)", kind: "text", placeholder: "Enter average lot thickness in inches"),
  build_question("Grade Tolerance (inches)", kind: "text", placeholder: "Enter grade tolerance in inches"),
  build_question("Surface Tolerance (straightedge)", kind: "text", placeholder: "Enter surface tolerance"),
  build_question("Discrepancies Noted?", kind: "radio", options: ["Yes", "No"]),
  build_question("Corrective Action Details", kind: "textarea", placeholder: "Describe corrective actions taken..."),
  build_question("Quantity Placed (Cu YDS)", kind: "number", placeholder: "Enter quantity placed in cubic yards", validation: { min: 0 }),
  build_question("Pavement Course Type", kind: "text", placeholder: "Enter pavement course type (e.g., leveling)"),
  build_question("Aggregate", kind: "text", placeholder: "Enter aggregate size (e.g., 1/2\")"),
  build_question("Mineral Filler", kind: "radio", options: ["Yes", "No"]),
  build_question("Asphalt Binder", kind: "radio", options: ["Yes", "No"]),
  build_question("Anti-stripping agent", kind: "radio", options: ["Yes", "No"]),
  build_question("Lab accreditation confirmed", kind: "radio", options: ["Yes", "No"]),
  build_question("Job Mix Formula ID", kind: "text", placeholder: "Enter job mix formula ID"),
  build_question("Control Strip Mat Density", kind: "text", placeholder: "Enter control strip mat density"),
  build_question("Control Strip Joint Density", kind: "text", placeholder: "Enter control strip joint density"),
  build_question("Air Voids", kind: "text", placeholder: "Enter air voids percentage"),
  build_question("Plant QC Gradation Count", kind: "text", placeholder: "Enter plant QC gradation count"),
  build_question("Plant QC Asphalt Content Count", kind: "text", placeholder: "Enter plant QC asphalt content count"),
  build_question("APA Test Result (mm)", kind: "text", placeholder: "Enter APA test result in mm"),
  build_question("Acceptance Lot ID", kind: "text", placeholder: "Enter acceptance lot ID"),
  build_question("Acceptance Test Date", kind: "date", placeholder: "Select acceptance test date"),
  build_question("Discrepancies Noted", kind: "radio", options: ["Yes", "No"]),
  build_question("Corrective Action Details", kind: "textarea", placeholder: "Describe corrective actions taken..."),
  build_question("Quantity Placed (Tons/Cu Yds)", kind: "number", placeholder: "Enter quantity placed", validation: { min: 0, step: 0.1 })
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
    "P-101" => { desc: "Mobilization", questions: default_questions },
    "P-102" => { desc: "Seeding and Mulching", questions: default_questions },
  },
  "Part 2 – Earthwork and Drainage" => {
    "P-209" => { desc: "Aggregate Base Course", questions: default_questions },
    "P-210" => { desc: "Aggregate Drainage Course", questions: default_questions },
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
    "P-610" => { desc: "Airfield Lighting Cable", questions: default_questions },
    "P-611" => { desc: "Airfield Lighting Equipment", questions: default_questions },
  },
  "Part 9 – Miscellaneous" => {
    "P-620" => { desc: "Runway and Taxiway Marking", questions: p620_questions },
    "P-603" => { desc: "Emulsified Asphalt Tack Coat", questions: default_questions },
    "P-625" => { desc: "Pavement Grooving", questions: default_questions },
  }
}

faa_specs.each do |division, items|
  items.each do |code, config|
    SpecItem.create!(
      code: code,
      description: config[:desc],
      division: division,
      checklist_questions: config[:questions]
    )
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
    
    bid_item = BidItem.create!(
      project: project_1,
      code: "RW1R-#{code}",
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
["Caterpillar D6 Dozer", "Volvo L120 Loader", "John Deere 850K Dozer", 
 "Caterpillar AP1000 Paver", "Wirtgen W210 Cold Mill", "Bomag BW213 Roller"].each do |equipment|
  ApprovedEquipment.create!(project: project_1, name: equipment)
end

["Caterpillar 320 Excavator", "Terex TA400 Haul Truck", "Hamm HD120 Roller",
 "Caterpillar AP600 Paver", "Roadtec RX700e Paver", "Bomag BW177 Roller"].each do |equipment|
  ApprovedEquipment.create!(project: project_2, name: equipment)
end

puts "📝 Maestro: Generating Sample Report for Project 1..."
report = Report.create!(
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
report_2 = Report.create!(
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

report_3 = Report.create!(
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

report_4 = Report.create!(
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

puts "✅ Maestro: Seeding Complete!"
puts "   Users:"
puts "     - admin@cms.com / cloudattack"
puts "     - tester@cms.com / cloudattack"
puts "   Projects: 2 (#{project_1.name}, #{project_2.name})"
puts "   Spec Divisions: #{faa_specs.keys.count} (all represented in both projects)"
puts "   Bid Items: #{BidItem.count} total"
puts "   Approved Equipment: #{ApprovedEquipment.count} items across projects"
puts "   Reports: 4 sample reports created (2 per user)"
