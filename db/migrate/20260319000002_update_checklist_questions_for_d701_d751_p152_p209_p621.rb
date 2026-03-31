class UpdateChecklistQuestionsForD701D751P152P209P621 < ActiveRecord::Migration[7.1]
  def up
    d701_questions = [
      bq("Is the trench width equal to the pipe diameter plus 12 inches on each side to allow proper jointing and compaction? - 701-3.1-¶1"),
      bq("Are trench walls excavated vertically and is rock removed to a minimum depth of 8 inches below the pipe grade? - 701-3.1-¶2"),
      bq("For rigid pipe bedding, is the maximum aggregate size 1 inch for bedding less than 6 inches thick, and 1-1/2 inches for bedding greater than 6 inches thick? - 701-3.2-a"),
      bq("Is pipe installation starting at the lowest point with bell or groove ends facing upgrade? - 701-3.3-¶1"),
      bq("Is the pipe barrel in full contact with the bedding surface with no voids or bridging? - 701-3.3-¶1"),
      bq("For concrete pipe joints, are ASTM C443 rubber gaskets being used and are mortar joints thoroughly wetted before application? - 701-3.4-a"),
      bq("Is embedment material placed in maximum 6-inch layers to a minimum height of 12 inches above the top of the pipe? - 701-3.5-2"),
      bq("Is embedment material placed evenly on both sides of the pipe to prevent displacement? - 701-3.5-2"),
      bq("Is trench overfill compacted to a minimum of 95% standard proctor density? - 701-3.6-¶2"),
      bq("Is the maximum stone size in overfill layers limited to one-half the layer thickness? - 701-3.6-¶2"),
      bq("Does the bedding surface deviate no more than 1/2 inch when tested with a 16-foot straightedge? - 1.04-C-1"),
      bq("Has pipe deflection testing been delayed a minimum of 30 days after completion of installation? - 701-3.7-¶1")
    ]

    d751_questions = [
      bq("Has the RPR approved the excavation before concrete and reinforcing steel placement? - 751-3.1-¶e"),
      bq("Has the RPR approved the reinforcement before concrete placement? - 751-3.3-¶1"),
      bq("Has the RPR approved the structure before backfilling operations begin? - 751-3.9-¶b"),
      bq("Has the concrete been allowed to harden for a minimum of 7 days before grates or covers are placed? - 751-3.7-¶2"),
      bq("Has the concrete been allowed to harden for a minimum of 7 days before steps are used? - 751-3.8-¶1"),
      bq("Has the concrete cured for a minimum of 7 days before backfilling? - 751-3.9-¶b"),
      bq("Are steps installed with a maximum vertical spacing of 12 inches? - 751-3.8-¶3"),
      bq("Are backfill materials placed in loose layers not exceeding 8 inches in depth? - 751-3.9-¶a"),
      bq("Is the structure elevation no more than 3 inches above the surrounding grade in safety areas? - 751-3.9-¶c"),
      bq("Are brick structure mortar joints between 1/4\" and 1/2\" (6-12 mm) in thickness? - 751-3.2-¶c")
    ]

    p152_questions = [
      bq("[152-2.8] Are earthwork operations suspended during rain, freezing conditions, or when the subgrade is frozen? - 152-2.8, Paragraph 4"),
      bq("[152-2.8] Is frozen material being rejected and not placed in embankments? - 152-2.8, Paragraph 4"),
      bq("[152-2.8] Is placement of fill material on muddy, frozen, or frost-covered surfaces prohibited? - 152-2.8, Paragraph 4"),
      bq("[152-2.7] Is the control strip being constructed during the first half-day of operations and witnessed by the RPR? - 152-2.7, Paragraph 1"),
      bq("[152-2.7] Has the RPR approved the control strip before full-scale operations begin? - 152-2.7, Paragraph 3"),
      bq("[152-2.8] Is each lift being placed at a compacted thickness between 6 inches and 12 inches? - 152-2.8, Paragraph 1"),
      bq("[152-2.8] Is the moisture content of placed material within +/-2% of the optimum moisture content? - 152-2.8, Paragraph 5"),
      bq("[152-2.8] Is non-cohesive embankment material being compacted to >=95% of ASTM D1557 maximum density? - 152-2.8, Paragraph 7"),
      bq("[152-2.8] Is cohesive embankment material being compacted to >=90% of ASTM D1557 maximum density? - 152-2.8, Paragraph 7"),
      bq("[152-2.8] Is subgrade in paved areas being compacted to >=95% maximum density to a depth of 12 inches? - 152-2.8, Paragraph 7"),
      bq("[152-2.8] Is subgrade in unpaved areas being compacted to >=95% of ASTM D698 maximum density to a depth of 6 inches? - 152-2.10, Paragraph 1"),
      bq("[152-2.8] Is embankment compaction testing being performed at a minimum frequency of one test per 3,000 square yards per lift? - 152-2.8, Paragraph 6"),
      bq("[152-2.8] Is subgrade compaction testing being performed at a minimum frequency of one test per 1,000 square yards? - 152-2.10, Paragraph 2"),
      bq("[152-2.9] Is proof rolling being performed with a 20-ton truck or 15-ton roller? - 152-2.9, Paragraph 1"),
      bq("[152-2.9] Are two complete coverages of the proof roller being applied to the subgrade? - 152-2.9, Paragraph 1"),
      bq("[152-2.9] Are areas showing deflection greater than 1 inch being rejected and reworked? - 152-2.9, Paragraph 1"),
      bq("[152-2.13] Does the finished surface vary no more than +/-1/2 inch in 12 feet when tested with a 12-foot straightedge? - 152-2.13(a)"),
      bq("[152-2.13] Is the finished grade of paved areas within +/-0.05 feet of the specified elevation? - 152-2.13(b)"),
      bq("[152-2.13] Is the finished grade of safety areas within +/-0.10 feet of the specified elevation? - 152-2.13, Paragraph 2")
    ]

    p209_questions = [
      bq("Has the control strip been constructed and accepted by the RPR before full production began? - 209-3.1"),
      bq("Has the subgrade been checked and accepted by the RPR prior to aggregate placement? - 209-3.2"),
      bq("Is the aggregate base being placed at a uniform thickness as specified in the plans? - 209-3.4"),
      bq("Is aggregate being placed directly in its final position without re-handling or manipulation? - 209-3.4"),
      bq("Is hauling equipment operating only over previously compacted base, avoiding travel over uncompacted material? - 209-3.4"),
      bq("Does field density testing show values >=100% of maximum laboratory density (ASTM D1557)? - 209-3.5"),
      bq("Is moisture content maintained within +/-2% of optimum moisture content during compaction operations? - 209-3.5"),
      bq("Is the air temperature at least 40 degrees F and rising at the time of placement? - 209-3.6"),
      bq("Is placement being performed on a dry, unfrozen subgrade free of standing water or frost? - 209-3.6"),
      bq("Does the finished surface deviate no more than 3/8 inch when tested with a 12-foot straightedge? - 209-3.8(a)"),
      bq("Is the finished grade within +0 to -1/2 inch of the specified design elevation? - 209-3.8(b)"),
      bq("Are density and thickness tests being performed at the required frequency of 2 tests per 2,400 square yards using random sampling locations? - 209-3.9")
    ]

    p621_questions = [
      bq("Has the control strip been grooved to demonstrate proper equipment setup and alignment procedures? - 621-2.3"),
      bq("Are grooves being cut cleanly without spalling or raveling of the pavement edges? - 621-2.6"),
      bq("Is slurry being continuously removed from the pavement surface during grooving operations? - 621-2.6"),
      bq("For new pavements, has a minimum 30-day cure period elapsed before grooving operations began? - 621-2.2"),
      bq("Are grooving operations suspended when freezing conditions prevent proper removal of debris and water? - 621-2.5"),
      bq("Are groove widths measuring 1/4 inch (+1/16\", -0\") as verified by field measurement? - 621-2.1"),
      bq("Are groove depths measuring 1/4 inch (+/-1/16\") as verified by field measurement? - 621-2.1"),
      bq("Is groove spacing measuring 1-1/2 inches (-1/8\", +0\") as verified by field measurement? - 621-2.1"),
      bq("Is the groove alignment maintained within +/-1-1/2 inches over any 75-foot length, with realignment performed every 500 feet? - 621-2.1a"),
      bq("Is the pavement surface being continuously cleaned during grooving operations with all debris and slurry removed from the site? - 621-2.8"),
      bq("Is acceptance testing being performed using zone testing across 5 zones of the pavement width at least 3 times per day? - 621-3.1")
    ]

    # Create or update D-701
    spec = SpecItem.find_or_initialize_by(code: "D-701")
    spec.description = "Pipe for Storm Drains and Culverts"
    spec.division = "Part 7 – Drainage and Utilities"
    spec.checklist_questions = d701_questions
    spec.save!

    # Create or update D-751
    spec = SpecItem.find_or_initialize_by(code: "D-751")
    spec.description = "Manholes, Catch Basins, Inlets, and Inspection Holes"
    spec.division = "Part 7 – Drainage and Utilities"
    spec.checklist_questions = d751_questions
    spec.save!

    # Update P-152
    if (spec = SpecItem.find_by(code: "P-152"))
      spec.update!(checklist_questions: p152_questions)
    end

    # Update P-209
    if (spec = SpecItem.find_by(code: "P-209"))
      spec.update!(checklist_questions: p209_questions)
    end

    # Remove P-625 (typo — replaced by P-621)
    if (spec = SpecItem.find_by(code: "P-625"))
      spec.bid_items.destroy_all
      spec.destroy
    end

    # Create or update P-621
    spec = SpecItem.find_or_initialize_by(code: "P-621")
    spec.description = "Runway and Taxiway Grooving"
    spec.division = "Part 9 – Miscellaneous"
    spec.checklist_questions = p621_questions
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

    if (spec = SpecItem.find_by(code: "D-701"))
      spec.bid_items.destroy_all
      spec.destroy
    end

    if (spec = SpecItem.find_by(code: "D-751"))
      spec.bid_items.destroy_all
      spec.destroy
    end

    if (spec = SpecItem.find_by(code: "P-152"))
      spec.update!(checklist_questions: default_questions)
    end

    if (spec = SpecItem.find_by(code: "P-209"))
      spec.update!(checklist_questions: default_questions)
    end

    if (spec = SpecItem.find_by(code: "P-621"))
      spec.bid_items.destroy_all
      spec.destroy
    end

    # Restore P-625
    spec = SpecItem.find_or_initialize_by(code: "P-625")
    spec.description = "Pavement Grooving"
    spec.division = "Part 9 – Miscellaneous"
    spec.checklist_questions = default_questions
    spec.save!
  end

  private

  def bq(prompt)
    SpecItem.build_question(prompt: prompt, kind: "radio", options: nil)
  end
end
