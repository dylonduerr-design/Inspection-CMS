class UpdateChecklistQuestionsForP101P151 < ActiveRecord::Migration[7.1]
  def up
    p101_questions = [
      bq("Has the removal operation been controlled to prevent damage to adjacent pavement, base material, and utilities that are to remain? - 101-3.1"),
      bq("Is asphalt pavement being cut to the full depth around the perimeter of the removal area? - 101-3.1b"),
      bq("If asphalt material is being wasted on the airport site, is it broken to a maximum size of 1 inch? - 101-3.1b"),
      bq("Is the joint for each layer of pavement replacement offset 1 foot from the joint in the preceding layer (unless otherwise shown on plans)? - 101-3.1b"),
      bq("Is all failed material (surface, base, subbase, and subgrade) being removed and repaired as shown on the plans or as directed by the RPR? - 101-3.1c"),
      bq("Is damage caused by the Contractor's removal process being repaired at the Contractor's expense? - 101-3.1c"),
      bq("Is milling producing a uniform finished surface? - 101-3.5"),
      bq("Is the milling machine operating without tearing or gouging the underlaying surface? - 101-3.5"),
      bq("Is the milling machine equipped with automatic grade/slope controls and positive dust control? - 101-3.5"),
      bq("Are all millings being removed and disposed of off Airport property (or used/stockpiled as specified)? - 101-3.5"),
      bq("Is the milling machine cutting vertical edges without chipping or spalling the remaining pavement edges? - 101-3.5a"),
      bq("Does the milling machine have a minimum width of 7 feet and electronic grade control devices? - 101-3.5b"),
      bq("Is the machine cutting vertical edges and using positive dust control? - 101-3.5b"),
      bq("Does the machine have the ability to windrow or remove millings and load them into a truck? - 101-3.5b"),
      bq("Is the milled surface being swept daily and immediately after milling until all residual materials are removed? - 101-3.5c"),
      bq("Prior to paving, is the milled pavement being wetted down and thoroughly swept/blown to loosen residual material? - 101-3.5c"),
      bq("Are waste materials being collected and removed from the pavement surface and adjacent areas by sweeping or vacuuming? - 101-3.5c"),
      bq("Are asphalt pavement surfaces softened by petroleum or failed areas being patched? - 101-3.6a"),
      bq("Is damaged pavement removed to full depth and replaced with new asphalt pavement similar to existing? - 101-3.6a"),
      bq("Are joints and cracks being repaired in accordance with paragraph 101-3.2? - 101-3.6b"),
      bq("Is oil or grease being removed by scrubbing with detergent and washing with clean water? - 101-3.6c"),
      bq("Are cleaned oil/grease areas being treated with oil spot primer? - 101-3.6c"),
      bq("Is the pavement surface clean and free of dust, dirt, grease, vegetation, oil, or objectionable film immediately prior to surface treatment? - 101-3.6d"),
      bq("Is the Contractor performing maintenance to keep pavement in satisfactory condition until acceptance? - 101-3.7"),
      bq("Is the surface being kept clean and free from foreign material? - 101-3.7"),
      bq("Is the pavement being kept properly drained at all times? - 101-3.7"),
      bq("Are joints being cleaned and dried of all scale, dirt, dust, old sealant, curing compound, moisture, and foreign matter prior to sealing? - 101-3.8"),
      bq("Has the Contractor demonstrated to the RPR that the cleaning method cleans the joint without damaging it? - 101-3.8")
    ]

    p151_questions = [
      bq("Are the clearing/grubbing limits properly staked on the ground as shown on the plans? - 151-2.1"),
      bq("Is clearing and grubbing being performed sufficiently in advance of grading operations? - 151-2.1"),
      bq("Are all cleared materials being disposed of outside the airport limits (unless otherwise directed by RPR)? - 151-2.1.1"),
      bq("Are any discarded materials being left in windrows or piles adjacent to or within the airport limits? (Verify NONE exist) - 151-2.1.1"),
      bq("Has the RPR approved the disposal manner and location? Does the disposal area create an unsightly or objectionable view? - 151-2.1.1"),
      bq("If using private property for disposal, has written permission from the property owner been obtained and filed with the RPR? - 151-2.1.1"),
      bq("Is blasting being used for any clearing operations? (Verify NONE) - 151-2.1.2"),
      bq("Has the staked area been cleared of all objectionable materials as indicated on the plans? - 151-2.2"),
      bq("Have any trees that fell outside the clearing limits been cut up, removed, and disposed of satisfactorily? - 151-2.2"),
      bq("Are trees being felled toward the center of the area being cleared to protect standing trees? - 151-2.2"),
      bq("Are all trees designated to remain protected from injury during clearing operations? - 151-2.2"),
      bq("Are trees, stumps, and brush cut flush with the original ground surface? - 151-2.2"),
      bq("Is fence wire neatly rolled and properly stored as directed by the RPR? - 151-2.2"),
      bq("In cleared and grubbed areas (excluding deep embankment zones outside paved areas), have all stumps, roots, buried logs, brush, grass, and unsatisfactory materials been removed? - 151-2.3"),
      bq("In embankment areas outside paved areas, are sound trees, stumps, and brush cut flush with original ground and allowed to remain? - 151-2.3"),
      bq("Are tap roots and projections over 1-1/2 inches diameter grubbed out to at least 18 inches below finished subgrade or slope elevation? - 151-2.3"),
      bq("Have all buildings and structures shown on plans for removal been demolished/removed with all materials disposed of off-site? - 151-2.3"),
      bq("Have foundations, wells, cesspools, and similar structures been broken down to at least 2 feet below existing ground level? - 151-2.3"),
      bq("Has objectionable material that cannot be used in backfill been removed and properly disposed of? - 151-2.3"),
      bq("Have holes and openings from removed structures been backfilled with acceptable material and properly compacted? - 151-2.3"),
      bq("Do holes in embankment areas have flattened sides to facilitate filling and compaction per P-152? - 151-2.3"),
      bq("In areas where grubbing holes exceed proposed excavation depth, have the hole sides been flattened for proper backfilling? - 151-2.3")
    ]

    # Update P-101
    if (spec = SpecItem.find_by(code: "P-101"))
      spec.update!(description: "Pavement Removal", checklist_questions: p101_questions)
    end

    # Create or update P-151
    spec = SpecItem.find_or_initialize_by(code: "P-151")
    spec.description = "Clearing and Grubbing"
    spec.division = "Part 1 – General Provisions"
    spec.checklist_questions = p151_questions
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

    if (spec = SpecItem.find_by(code: "P-101"))
      spec.update!(description: "Mobilization", checklist_questions: default_questions)
    end

    if (spec = SpecItem.find_by(code: "P-151"))
      spec.bid_items.destroy_all
      spec.destroy
    end
  end

  private

  def bq(prompt)
    SpecItem.build_question(prompt: prompt, kind: "radio", options: nil)
  end
end
