class UpdateChecklistQuestionsForP620 < ActiveRecord::Migration[7.1]
  def up
    p620_questions = [
      # 620-3.1 Weather Limitations
      bq("Is the pavement surface dry prior to marking operations? - 620-3.1"),
      bq("Does the ambient temperature meet the paint manufacturer's minimum requirements? - 620-3.1"),
      bq("Does the pavement surface temperature meet the paint manufacturer's minimum requirements? - 620-3.1"),
      bq("Is the wind speed at or below 10 mph, or are windscreens in use to shroud the material guns? - 620-3.1"),
      bq("Are weather conditions forecasted to remain within the manufacturer's recommendations for application and dry time? - 620-3.1"),

      # 620-3.2 Equipment
      bq("Is the marking machine an atomizing spray-type or airless-type with automatic glass bead dispensers? - 620-3.2"),
      bq("Does the marking machine produce an even and uniform film thickness with clear-cut edges, without running or spattering? - 620-3.2"),
      bq("Has the marking equipment (paint and beads) been calibrated today? - 620-3.2"),

      # 620-3.3 Preparation of Surfaces
      bq("Is the surface free from dirt, grease, oil, laitance, and other contaminants immediately prior to paint application? - 620-3.3"),
      bq("If chemicals or impact abrasives were used for surface preparation, was RPR approval obtained in advance? - 620-3.3"),
      bq("After cleaning, was the surface swept, blown, or rinsed with pressurized water to remove all grit and debris? - 620-3.3"),
      bq("For new pavement surfaces: was the area cleaned by broom, blower, water blasting, or other RPR-approved method to remove all contaminants including PCC curing compounds? - 620-3.3a"),
      bq("For removal of existing markings: were markings removed by rotary grinding, water blasting, or other RPR-approved method minimizing damage to the pavement surface? - 620-3.3b"),
      bq("For removal of existing markings on asphalt: was a fog seal or seal coat applied to block out the removal area and eliminate ghost markings? - 620-3.3b"),
      bq("For remarking over existing markings: were loose existing markings removed with an RPR-approved method and the surface cleaned of all residue? - 620-3.3c"),
      bq("Has the Contractor submitted written certification that the surface is dry and free from all foreign material, along with a copy of the paint manufacturer's application and surface preparation requirements, to the RPR prior to initial marking application? - 620-3.3c"),

      # 620-3.4 Layout of Markings
      bq("Have the proposed markings been laid out in advance of paint application? - 620-3.4"),
      bq("Are the locations of markings to receive glass beads shown on the plans and verified in the layout? - 620-3.4"),

      # 620-3.5 Application
      bq("Has a minimum 30-day period elapsed since placement of surface course or seal coat (or is a deviation specified in the General Contract Provisions or construction phasing plans)? - 620-3.5"),
      bq("Has the RPR approved the layout and condition of the surface prior to paint application? - 620-3.5"),
      bq("Is paint being applied at the locations, dimensions, and spacing shown on the plans without the addition of thinner? - 620-3.5"),
      bq("Do marking edges deviate no more than 1/2 inch (12 mm) from a straight line over any 50-foot (15 m) length? - 620-3.5"),
      bq("Are marking dimensions and spacing within the specified tolerances (±1/2\" for ≤36\", ±1\" for >36\" to 6', ±2\" for >6' to 60', ±3\" for >60')? - 620-3.5"),
      bq("Are glass beads being distributed upon marked areas immediately after paint application? - 620-3.5"),
      bq("Are glass beads being applied at the rate shown in Table 1 and adhering to the cured paint? - 620-3.5"),
      bq("Are glass beads being omitted from black and green paint areas? - 620-3.5"),
      bq("Are different bead types being kept separate and not mixed during application? - 620-3.5"),
      bq("Is regular monitoring of glass bead embedment and distribution being performed? - 620-3.5"),

      # 620-3.6 Preformed Thermoplastic (conditional — ask when applicable)
      bq("If preformed thermoplastic markings are being applied: is the heater a variable speed self-propelled unit with a heating width of no less than 16 feet and free span of no less than 18 feet? - 620-3.6"),
      bq("If preformed thermoplastic markings are being applied: is the pavement clean, dry, and free of debris, and has a non-VOC sealer (max 250 centiPoise) been applied shortly before marking? - 620-3.6"),

      # 620-3.7 Control Strip
      bq("Prior to full application, did the Contractor prepare a control strip in the presence of the RPR, demonstrating the surface preparation method and all striping equipment? - 620-3.7"),
      bq("Does the control strip confirm the marking equipment achieves the prescribed paint application rate and glass bead population (per Table 1), with beads properly embedded and evenly distributed? - 620-3.7"),
      bq("Were the control strip markings evaluated during darkness to verify uniform appearance prior to RPR acceptance? - 620-3.7"),

      # 620-3.8 Retro-Reflectance
      bq("Is retro-reflectance being measured with a portable retro-reflectometer meeting ASTM E1710 (or equivalent)? - 620-3.8"),
      bq("Are a total of 6 readings being taken over a 6 square foot area (3 readings from each direction)? - 620-3.8"),
      bq("Does the average retro-reflectance reading meet or exceed the minimum value for the material type and color (white/yellow/red per Table)? - 620-3.8"),
      bq("Are all 6 readings within 30% of each other? - 620-3.8"),

      # 620-3.9 Protection and Cleanup
      bq("Are all markings being protected from damage (moisture, spatter, splashes, spillage, drippings) until dry? - 620-3.9"),
      bq("Is the Contractor removing all debris, waste, and loose reflective media from the work area to the satisfaction of the RPR? - 620-3.9"),
      bq("Are waste materials being disposed of in compliance with all applicable state, local, and Federal environmental regulations? - 620-3.9")
    ]

    if (spec = SpecItem.find_by(code: "P-620"))
      spec.update!(checklist_questions: p620_questions)
    end
  end

  def down
    old_questions = [
      bq("Surface clean and dry?"),
      bq("Layout approved?"),
      bq("Paint type/color verified?"),
      { "id" => "film_thickness_mils", "prompt" => "Film thickness (mils)", "kind" => "number", "required" => false, "validation" => { "min" => 10, "max" => 25 } },
      bq("Glass beads applied?"),
      { "id" => "bead_application_rate_lbsgal", "prompt" => "Bead application rate (lbs/gal)", "kind" => "number", "required" => false, "validation" => { "min" => 5, "max" => 15, "step" => 0.5 } },
      { "id" => "drying_time_observed_minutes", "prompt" => "Drying time observed (minutes)", "kind" => "number", "required" => false },
      { "id" => "retroreflectivity_reading_mcdm2lux", "prompt" => "Retroreflectivity reading (mcd/m²/lux)", "kind" => "number", "required" => false },
      bq("Photos taken?")
    ]

    if (spec = SpecItem.find_by(code: "P-620"))
      spec.update!(checklist_questions: old_questions)
    end
  end

  private

  def bq(prompt)
    SpecItem.build_question(prompt: prompt, kind: "radio", options: nil)
  end
end
