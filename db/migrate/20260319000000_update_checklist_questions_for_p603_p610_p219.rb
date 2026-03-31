class UpdateChecklistQuestionsForP603P610P219 < ActiveRecord::Migration[7.1]
  def up
    p603_questions = [
      bq("Is the existing surface dry at the time of application? - 603-3.1"),
      bq("Is the atmospheric temperature 50°F or above and are weather conditions free from fog and rain at the time of application? - 603-3.1"),
      bq("If temperature requirements are waived, is written direction from the RPR on file? - 603-3.1"),
      bq("Is the equipment in good working order? - 603-3.2"),
      bq("Is the distributor tank free of contaminants and diluents? - 603-3.2"),
      bq("Are spray bar tips clean and free of burrs? - 603-3.2"),
      bq("Is the application speed maintained under 8 mph (700 ft/min)? - 603-3.2"),
      bq("Are predetermined flow rates and constant pressure maintained during application? - 603-3.2"),
      bq("Is the surface cleaned of all dust, dirt, loose material, and foreign matter immediately before application? - 603-3.3"),
      bq("Is the surface dry before application of the tack coat? - 603-3.3"),
      bq("Does the tack coat provide uniform coverage without streaks? - 603-3.4"),
      bq("Does the tack coat provide uniform coverage without bare spots? - 603-3.4"),
      bq("Has the tack coat broken (water evaporated leaving asphalt residue) before asphalt mixture placement? - 603-3.4")
    ]

    p610_questions = [
      bq("Is slump tested per ASTM C143 and not exceeding 4 inches (100 mm)? - 610-3.2"),
      bq("Have all forms and reinforcements been inspected and approved by RPR before concrete placement? - 610-3.4"),
      bq("Are forms true to line and grade, mortar-tight, and rigid (no displacement or sagging)? - 610-3.4"),
      bq("Are form surfaces smooth and free from irregularities, dents, sags, and holes? - 610-3.4"),
      bq("Are internal form ties arranged so no metal shows or discolors the concrete surface after form removal? - 610-3.4"),
      bq("Is reinforcement accurately placed per plans and firmly held in position during placement? - 610-3.5"),
      bq("Is concrete dropped from a height of 5 feet (1.5 m) or less? - 610-3.8"),
      bq("Is vibration being performed in accordance with ACI 309R guidelines? - 610-3.9"),
      bq("When placing concrete below 40°F (4°C), are ACI 306R cold weather concreting recommendations being followed? - 610-3.13"),
      bq("When placing concrete above 85°F (30°C), are ACI 305R hot weather concreting recommendations being followed? - 610-3.14")
    ]

    p219_questions = [
      bq("Has the subgrade been compacted to the required density prior to base course placement? - 219-3.1"),
      bq("Is each lift of base course 8 inches (200 mm) or less in compacted thickness? - 219-3.3"),
      bq("Is the material placed to the lines, grades, and cross-sections shown on the plans? - 219-3.3"),
      bq("Is material being placed and compacted within 24 hours of delivery to the site? - 219-3.3"),
      bq("Is the compacted base course achieving a minimum of 95% of maximum density (ASTM D1557)? - 219-3.4"),
      bq("Is the moisture content within +/- 2% of optimum moisture content prior to rolling? - 219-3.4"),
      bq("Are areas failing to meet specified density being reworked and re-compacted until density requirements are achieved? - 219-3.4"),
      bq("Is the finished surface smooth and free from ruts, depressions, or irregularities? - 219-3.5"),
      bq("Are areas failing smoothness, grade, or crown requirements being scarified to at least 3 inches (75 mm), reshaped, and re-compacted? - 219-3.6"),
      bq("Are all final smoothness and grade checks being performed in the presence of the RPR? - 219-3.6"),
      bq("Does the finished surface vary no more than +/- 1/2 inch (12 mm) when tested with a 12-foot straightedge? - 219-3.6(a)"),
      bq("Is grade and crown being measured on a 50-foot grid? - 219-3.6(b)"),
      bq("Is the measured grade and crown within +/- 0.05 feet (15 mm) of the specified grade? - 219-3.6(b)"),
      bq("Is the base course thickness within +0 and -1/2 inch (12 mm) of specified thickness? - 219-3.8"),
      bq("Are depth tests for thickness being taken by the Contractor in the presence of the RPR? - 219-3.8"),
      bq("Are areas deficient by more than 1/2-inch (12 mm) being removed to full depth and replaced at Contractor's expense? - 219-3.8"),
      bq("Are surveys being conducted before and after base placement on a minimum 25ft x 25ft grid (if survey method is used for thickness)? - 219-3.8")
    ]

    # Update P-603
    if (spec = SpecItem.find_by(code: "P-603"))
      spec.update!(checklist_questions: p603_questions)
    end

    # Update P-610
    if (spec = SpecItem.find_by(code: "P-610"))
      spec.update!(description: "Concrete for Miscellaneous Structures", checklist_questions: p610_questions)
    end

    # Create or update P-219
    spec = SpecItem.find_or_initialize_by(code: "P-219")
    spec.description = "Recycled Concrete Aggregate Base Course"
    spec.division = "Part 2 – Earthwork and Drainage"
    spec.checklist_questions = p219_questions
    spec.save!
  end

  def down
    default_questions = [
      bq("Material submittals approved?"),
      bq("Weather conditions acceptable?"),
      bq("Equipment clean and functional?"),
      bq("Grade and alignment checked?"),
      bq("Safety requirements met?"),
      bq("Photos taken?")
    ]

    if (spec = SpecItem.find_by(code: "P-603"))
      spec.update!(checklist_questions: default_questions)
    end

    if (spec = SpecItem.find_by(code: "P-610"))
      spec.update!(description: "Airfield Lighting Cable", checklist_questions: default_questions)
    end

    if (spec = SpecItem.find_by(code: "P-219"))
      spec.bid_items.destroy_all
      spec.destroy
    end
  end

  private

  def bq(prompt)
    SpecItem.build_question(prompt: prompt, kind: "radio", options: nil)
  end
end
