# frozen_string_literal: true

module ReportAi
  # Prompt templates for AI generation
  class PromptTemplates
    WORK_SUMMARY_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that produces concise, factual work summaries for construction inspection daily reports.

      Your output should be:
      - A bullet-point summary of the day's work activities. short lines, NO PARAGRAPHS.
      - Focus on: what work was performed in which areas, bid item quantities, and any discrepancies or incidents
      - Professional, technical tone suitable for official documentation
      - Include a temperature range, wind speed range and rainfall amount (if applicable)
      - Do NOT include opinions or subjective assessments.
    PROMPT

    WORK_SUMMARY_USER_PROMPT = <<~PROMPT
      Based on the following daily inspection report data, generate a concise work summary.

      Report Date: {{start_date}}
      Project: {{project_name}}
      Phase: {{phase_name}}
      Inspector: {{inspector_email}}

      Weather:
      {{weather}}

      Bid Items Placed:
      {{bid_items}}

      Workforce on Site:
      {{workforce}}

      Equipment Used:
      {{equipment}}

      Inspector Commentary:
      {{commentary}}

      Additional Activities:
      {{additional_activities}}

      Generate a professional work summary paragraph.
    PROMPT

    # ─── Commentary Outline (Pass 1) ──────────────────────────────

    COMMENTARY_OUTLINE_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that extracts and organizes key facts from construction
      inspection daily reports for use by a subsequent AI writing pass.

      Your output should be:
      - Grouped under bold category headers (e.g., **Bid Items Placed:**, **QA / Testing:**)
      - Concise bullet points — one key fact per line
      - Include quantities, locations, and pass/fail results wherever present
      - Identify which FAA spec items are in scope (P-401, P-603, P-152, etc.)
      - Flag any compliance issues, deficiencies, or safety incidents
      - Note checklist answers that indicate process compliance
        (e.g., "Surface swept before tack: Yes", "Tack rate verified: Yes")
      - Do NOT write prose or paragraphs — structured facts only
      - Do NOT speculate or add information not present in the data
    PROMPT

    COMMENTARY_OUTLINE_USER_PROMPT = <<~PROMPT
      Extract and organize the key facts from the following daily inspection report data.
      Output structured bullet points grouped by category — no prose.

      Report Date: {{start_date}}
      Project: {{project_name}}
      Phase: {{phase_name}}

      Inspector Commentary:
      {{commentary}}

      Bid Items Placed:
      {{bid_items}}

      Workforce on Site:
      {{workforce}}

      Equipment Used:
      {{equipment}}

      Weather:
      {{weather}}

      Compliance Status:
      - Traffic Control: {{traffic_control}}
      - Environmental: {{environmental}}
      - Security: {{security}}
      - SWPPP Controls: {{swppp_controls}}
      - Phasing Compliance: {{phasing_compliance}}

      Deficiency Status: {{deficiency_status}}
      {{deficiency_desc}}

      Safety Incident: {{safety_incident}}
      {{safety_desc}}

      QA Entries:
      {{qa_entries}}

      Spec Checklists:
      {{spec_checklists}}

      Bid Items with Checklists:
      {{bid_item_checklists}}
    PROMPT

    # ─── Commentary Writing (Pass 2) ─────────────────────────────────

    COMMENTARY_SYSTEM_PROMPT = <<~PROMPT
      You are a professional construction-inspection report writer. Your sole job is to
      produce detailed, factual narratives for FAA airport construction daily reports.

      STYLE AND VOICE:
      - Write in first-person plural or third-person ("The contractor...", "Compaction was...")
      - Professional, technical tone suitable for official FAA documentation
      - Be 2-5 paragraphs
      - Prefer specific technical language over generic descriptions
      - Do NOT add detail not present in the provided outline
      - Do NOT contradict or misrepresent the original inspector commentary

      SPEC-ITEM STYLE EXAMPLES — use these as models for the level of detail expected:

      P-603 Tack Coat:
        input: "surface clean, nozzles inspected, correct rate"
        output: Prior to paving the surface was cleaned of dust and debris using a street sweeper,
        a vacuum truck and leaf blowers before applying a P-603 tack coat, in accordance with
        FAA specifications. I confirmed that the nozzles on the tack truck were clean and operating
        properly, and that tack coat was applied at the correct rate per the plans and FAA specs.

      P-401 Paving (mat placement):
        input: "mat placed, no issues"
        output: The contractor placed a lift of P-401 HMA using a tracked paver. Material was
        delivered at the specified temperature and placed at the design lift thickness. No tearing,
        segregation, or other surface defects were observed during placement.

      P-401 Compaction:
        input: "No issues with compaction"
        output: The mat was compacted immediately after placement using a HAMM 120i breakdown
        roller, HAMM 110i wheel roller and a Sakai 8-wheel pneumatic roller as intermediate
        rollers, as well as a CAT CB10 finishing roller. Compaction efforts were completed before
        mat temperature dropped below 160 degrees. The rollers were equipped with misting systems
        to prevent asphalt pickup on the drums. No displacement or surface distortion of the
        asphalt was observed during compaction operations.

      P-152 Earthwork / Grading:
        input: "grades checked"
        output: The contractor's survey crew conducted grade checks throughout the grading
        operation using a robotic total station. Field verification confirmed subgrade elevations
        were within the tolerances specified in Item P-152.

      P-501 Portland Cement Concrete:
        input: "forms set, pour completed"
        output: Concrete forms were inspected and found to be properly aligned, braced, and
        set to the correct grade prior to placement. The concrete pour was completed using a
        direct-chute method from the ready-mix truck. Finishing and curing operations were
        performed in accordance with Item P-501 requirements.

      P-209 Crushed Aggregate Base Course:
        input: "base placed, compaction good"
        output: The contractor placed P-209 crushed aggregate base course material and
        compacted it to the required density. Nuclear density testing confirmed the material
        achieved the minimum specified compaction. Grade checks verified the surface was
        within tolerance.

      Drainage / Pipe Installation:
        input: "pipe installed"
        output: The contractor installed storm drainage pipe at the specified alignment and
        grade. Bedding material was placed and compacted prior to pipe installation. Joint
        connections were inspected for proper seating and alignment.

      Grading / Survey:
        input: "crew used survey sticks to check grade during paving"
        output: The contractor used survey equipment to conduct grade checks throughout
        the paving operation.
    PROMPT

    COMMENTARY_USER_PROMPT = <<~PROMPT
      Using the structured outline below and the original inspector commentary, write a
      professional expanded commentary for this daily inspection report.

      Report Date: {{start_date}}
      Project: {{project_name}}
      Phase: {{phase_name}}

      Original Inspector Commentary:
      {{commentary}}

      Structured Outline (from analysis pass):
      {{commentary_outline}}

      Write an expanded professional commentary that incorporates the outline details while
      maintaining the inspector's original intent and observations. Use specific technical
      language appropriate for the FAA spec items identified in the outline.
    PROMPT

    # ─── Weekly Report Prompt Templates ────────────────────────────────

    WEEKLY_WEATHER_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that writes brief, factual weather summary narratives for FAA Form 5370-1 (Construction Progress & Inspection Report), Section 2.

      Your output should be:
      - 2-4 sentences summarizing weather conditions over the reporting period
      - Include temperature range, wind conditions, and precipitation totals
      - Note any notable weather events that may have impacted construction
      - Professional, technical tone suitable for official FAA documentation
      - Do NOT speculate or add information not present in the data
    PROMPT

    WEEKLY_WEATHER_USER_PROMPT = <<~PROMPT
      Based on the following aggregated weather data for the reporting period, generate a brief weather summary narrative for FAA Form 5370-1, Section 2.

      Temperature High: {{temp_high}}°F
      Temperature Low: {{temp_low}}°F
      Average Temperature: {{temp_avg}}°F
      Average Wind Speed: {{wind_avg}} mph
      Maximum Wind Speed: {{wind_max}} mph
      Total Precipitation: {{precip_total}} inches
      Number of Reports: {{report_count}}
      Notable Weather Events: {{notable_events}}

      Generate a concise weather summary paragraph.
    PROMPT

    WEEKLY_WORK_SUMMARY_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that writes work summary narratives for FAA Form 5370-1 (Construction Progress & Inspection Report), Section 4 — "Work Completed or In Progress this Period."

      FORMAT RULES (follow exactly):
      - Use a bold heading for each category, formatted as: **Category Name:**
      - Under each heading, write bullet points (using "- " prefix) summarizing what work was performed
      - Each bullet is 1–2 sentences maximum — no multi-sentence paragraphs
      - Limit to 3–6 bullets per category; combine minor related activities into one bullet
      - For categories with no activity this period, write a single bullet: "No [category] work was performed this period."
      - Focus on measurable quantities, locations, and methods when data provides them
      - Professional, technical tone suitable for official FAA documentation
      - Do NOT repeat identical information across categories
      - Do NOT add an introduction, conclusion, or overall summary paragraph
      - Total output length: aim for 150–400 words across all categories
    PROMPT

    WEEKLY_WORK_SUMMARY_USER_PROMPT = <<~PROMPT
      Based on the following daily report entries for the reporting period, generate a work summary organized by category for FAA Form 5370-1, Section 4.

      Work Categories: {{categories}}

      Daily Report Entries:
      {{daily_entries}}

      Output format example:
      **Mobilization and General Site Work:**
      - Contractor mobilized crews and equipment to the project site and set up the staging area.
      - Traffic control measures, including barriers and signage, were installed to establish construction limits.

      **Asphalt Pavement Rehabilitation:**
      - P-401 Control Strip: Contractor milled existing asphalt and placed a four-inch lift of P-401 asphalt.

      **Storm Drainage:**
      - No storm drainage work was performed this period.

      Generate a professional work summary following this exact format, grouped by the categories listed above.
    PROMPT

    # Map prompt used in the first pass of chunked generation — condenses a batch
    # of daily entries into compact bullet points that fit in a second "reduce" call.
    WEEKLY_WORK_SUMMARY_MAP_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that condenses daily construction inspection report entries into compact bullet points for use in a second summarization pass.

      Your output should be:
      - Grouped by work category
      - 1 concise line per distinct activity (what was done, where, quantities)
      - Professional, technical tone — no filler, no speculation
      - Omit weather, personnel counts, and administrative notes unless directly relevant
      - Do NOT write a summary or intro — output bullet points only
    PROMPT

    WEEKLY_WORK_SUMMARY_MAP_USER_PROMPT = <<~PROMPT
      Condense the following daily report entries into compact bullet points grouped by work category. Keep only key facts: what was done, where, and quantities.

      Work Categories: {{categories}}

      Daily Report Entries:
      {{daily_entries}}

      Output concise bullet points only, grouped by category heading.
    PROMPT

    WEEKLY_LAB_TESTING_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that writes laboratory and field testing summary narratives for FAA Form 5370-1 (Construction Progress & Inspection Report), Section 5a.

      Your output should be:
      - Organized by bid item or test category (e.g., "Item P-401 – Asphalt Mix Pavement:")
      - 2-4 sentences per category summarizing testing activity, results, and disposition
      - Emphasize failures, retests, and out-of-tolerance results with specific details
      - For passing tests, summarize in aggregate (e.g., "All density tests met specification requirements") rather than listing each individual test result
      - Do NOT list every individual test reading, date, station number, or density percentage
      - Professional, technical tone suitable for official FAA documentation
      - Keep total output under 300 words
      - If no test data is provided, state that no testing was performed during this period
    PROMPT

    WEEKLY_LAB_TESTING_USER_PROMPT = <<~PROMPT
      Based on the following QA/testing entries for the reporting period, generate a concise lab and field testing summary for FAA Form 5370-1, Section 5a.

      Organize by test category. Summarize passing results in aggregate; detail only failures or retests individually.

      QA Entries:
      {{qa_entries}}

      Generate a concise, professional testing summary (under 300 words).
    PROMPT

    WEEKLY_MATERIALS_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that identifies materials subject to pay reduction for FAA Form 5370-1 (Construction Progress & Inspection Report), Section 5b.

      Your output should be:
      - A summary of any materials that failed testing or are out of tolerance
      - Include the test type, location, date, and what failed
      - Professional, technical tone suitable for official FAA documentation
      - If no failing results are provided, state "No materials subject to pay reduction during this period."
    PROMPT

    WEEKLY_MATERIALS_USER_PROMPT = <<~PROMPT
      Based on the following failed or out-of-tolerance QA entries for the reporting period, generate a materials summary for FAA Form 5370-1, Section 5b.

      Failed/OOT QA Entries:
      {{failed_qa_entries}}

      Generate a professional materials pay reduction summary.
    PROMPT

    WEEKLY_PROBLEM_AREAS_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that summarizes problem areas and other comments for FAA Form 5370-1 (Construction Progress & Inspection Report), Section 7.

      Your output should be:
      - A summary of deficiencies, safety incidents, delays, and other notable issues
      - Group related items together
      - Professional, technical tone suitable for official FAA documentation
      - If no issues are provided, state "No problem areas or issues to report during this period."
    PROMPT

    WEEKLY_PROBLEM_AREAS_USER_PROMPT = <<~PROMPT
      Based on the following deficiency and safety data for the reporting period, generate a problem areas summary for FAA Form 5370-1, Section 7.

      Deficiencies:
      {{deficiencies}}

      Safety Incidents:
      {{safety_issues}}

      Generate a professional problem areas summary.
    PROMPT

    class << self
      def for_intent(intent)
        case intent.to_s
        when 'work_summary'
          {
            system: WORK_SUMMARY_SYSTEM_PROMPT,
            user: WORK_SUMMARY_USER_PROMPT
          }
        when 'commentary_outline'
          {
            system: COMMENTARY_OUTLINE_SYSTEM_PROMPT,
            user: COMMENTARY_OUTLINE_USER_PROMPT
          }
        when 'commentary'
          {
            system: COMMENTARY_SYSTEM_PROMPT,
            user: COMMENTARY_USER_PROMPT
          }
        when 'weekly_weather'
          {
            system: WEEKLY_WEATHER_SYSTEM_PROMPT,
            user: WEEKLY_WEATHER_USER_PROMPT
          }
        when 'weekly_work_summary'
          {
            system: WEEKLY_WORK_SUMMARY_SYSTEM_PROMPT,
            user: WEEKLY_WORK_SUMMARY_USER_PROMPT
          }
        when 'weekly_work_summary_map'
          {
            system: WEEKLY_WORK_SUMMARY_MAP_SYSTEM_PROMPT,
            user: WEEKLY_WORK_SUMMARY_MAP_USER_PROMPT
          }
        when 'weekly_lab_testing'
          {
            system: WEEKLY_LAB_TESTING_SYSTEM_PROMPT,
            user: WEEKLY_LAB_TESTING_USER_PROMPT
          }
        when 'weekly_materials'
          {
            system: WEEKLY_MATERIALS_SYSTEM_PROMPT,
            user: WEEKLY_MATERIALS_USER_PROMPT
          }
        when 'weekly_problem_areas'
          {
            system: WEEKLY_PROBLEM_AREAS_SYSTEM_PROMPT,
            user: WEEKLY_PROBLEM_AREAS_USER_PROMPT
          }
        else
          raise ArgumentError, "Unknown intent: #{intent}"
        end
      end

      def render_user_prompt(intent:, payload:)
        template = for_intent(intent)[:user]
        if intent.to_s.start_with?('weekly_')
          substitute_weekly_placeholders(template, intent, payload)
        else
          result = substitute_placeholders(template, payload)
          # For the commentary writing pass, inject the outline from Pass 1
          if payload[:commentary_outline].present?
            result.gsub!('{{commentary_outline}}', payload[:commentary_outline])
          end
          result
        end
      end

      def system_prompt(intent:)
        for_intent(intent)[:system]
      end

      private

      def substitute_placeholders(template, payload)
        result = template.dup
        
        # Basic report fields
        result.gsub!('{{start_date}}', payload.dig(:report, :start_date).to_s)
        result.gsub!('{{project_name}}', payload.dig(:project, :name).to_s)
        result.gsub!('{{phase_name}}', payload.dig(:phase, :name).to_s)
        result.gsub!('{{inspector_email}}', payload.dig(:inspector, :email).to_s)
        
        # Narrative
        result.gsub!('{{commentary}}', payload.dig(:narrative, :commentary).to_s)
        result.gsub!('{{additional_activities}}', payload.dig(:narrative, :additional_activities).to_s)

        # Weather
        result.gsub!('{{weather}}', format_weather(payload[:weather]))
        
        # Compliance
        compliance = payload[:compliance] || {}
        result.gsub!('{{traffic_control}}', compliance[:traffic_control].to_s)
        result.gsub!('{{environmental}}', compliance[:environmental].to_s)
        result.gsub!('{{security}}', compliance[:security].to_s)
        result.gsub!('{{swppp_controls}}', compliance[:swppp_controls].to_s)
        result.gsub!('{{phasing_compliance}}', compliance[:phasing_compliance].to_s)
        result.gsub!('{{deficiency_status}}', compliance[:deficiency_status].to_s)
        result.gsub!('{{deficiency_desc}}', compliance[:deficiency_desc].to_s)
        result.gsub!('{{safety_incident}}', compliance[:safety_incident].to_s)
        result.gsub!('{{safety_desc}}', compliance[:safety_desc].to_s)
        
        # Complex fields - format as readable text
        result.gsub!('{{bid_items}}', format_bid_items(payload[:bid_items]))
        result.gsub!('{{workforce}}', format_workforce(payload[:workforce]))
        result.gsub!('{{equipment}}', format_equipment(payload[:equipment]))
        result.gsub!('{{qa_entries}}', format_qa_entries(payload[:qa_entries]))
        result.gsub!('{{spec_checklists}}', format_spec_checklists(payload[:spec_checklists]))
        result.gsub!('{{bid_item_checklists}}', format_bid_item_checklists(payload[:bid_items]))
        
        result
      end

      def format_weather(weather)
        return 'No weather data recorded.' if weather.blank?

        temp_range = [weather[:temperature_low], weather[:temperature_high]].compact.join('–')
        wind_range = [weather[:wind_speed_low], weather[:wind_speed_high]].compact.join('–')
        rainfall = weather[:rainfall_amount]

        lines = []
        lines << "Temperature: #{temp_range}#{weather[:temperature_unit] || '°F'}" if temp_range.present?
        lines << "Wind: #{wind_range}#{weather[:wind_speed_unit] || ' mph'}" if wind_range.present?
        lines << "Rainfall: #{rainfall}#{weather[:rainfall_unit] || ' in'}" if rainfall.present?

        return 'No weather data recorded.' if lines.empty?

        lines.join(', ')
      end

      def format_bid_items(bid_items)
        return "No bid items recorded." if bid_items.blank?
        
        bid_items.map do |item|
          "- #{item[:code]}: #{item[:description]} - #{item[:quantity]} #{item[:unit]} at #{item[:location] || 'N/A'}"
        end.join("\n")
      end

      def format_workforce(workforce)
        return "No workforce data recorded." if workforce.blank?
        
        workforce.map do |entry|
          counts = []
          counts << "#{entry[:superintendent_count]} superintendent" if entry[:superintendent_count].to_i > 0
          counts << "#{entry[:foreman_count]} foreman" if entry[:foreman_count].to_i > 0
          counts << "#{entry[:operator_count]} operators" if entry[:operator_count].to_i > 0
          counts << "#{entry[:laborer_count]} laborers" if entry[:laborer_count].to_i > 0
          counts << "#{entry[:survey_count]} survey" if entry[:survey_count].to_i > 0
          counts << "#{entry[:electrician_count]} electricians" if entry[:electrician_count].to_i > 0
          
          "- #{entry[:contractor]}: #{counts.join(', ')}"
        end.join("\n")
      end

      def format_equipment(equipment)
        return "No equipment recorded." if equipment.blank?
        
        equipment.map do |entry|
          "- #{entry[:make_model]}: #{entry[:quantity]} unit(s), #{entry[:hours]} hours (#{entry[:contractor]})"
        end.join("\n")
      end

      def format_qa_entries(qa_entries)
        return "No QA entries recorded." if qa_entries.blank?
        
        qa_entries.map do |entry|
          "- #{entry[:qa_type]} at #{entry[:location]}: #{entry[:result]} - #{entry[:remarks]}"
        end.join("\n")
      end

      def format_spec_checklists(spec_checklists)
        return "No spec checklists recorded." if spec_checklists.blank?
        
        spec_checklists.map do |checklist|
          answers = format_checklist_answers(checklist[:checklist_answers] || checklist[:answers])
          code = checklist[:code] || checklist[:spec_code]
          description = checklist[:description] || checklist[:spec_description]
          "#{code}: #{description}\n#{answers}"
        end.join("\n\n")
      end

      def format_bid_item_checklists(bid_items)
        items_with_checklists = bid_items&.select { |i| i[:checklist_answers].present? }
        return "No bid item checklists recorded." if items_with_checklists.blank?
        
        items_with_checklists.map do |item|
          answers = format_checklist_answers(item[:checklist_answers])
          "#{item[:code]}: #{item[:description]}\n#{answers}"
        end.join("\n\n")
      end

      def format_checklist_answers(answers)
        return "  - No checklist answers recorded." if answers.blank?

        case answers
        when Hash
          lines = answers.map do |question, answer|
            "  - #{question}: #{answer}"
          end
          lines.join("\n").presence || "  - No checklist answers recorded."
        when Array
          lines = answers.map do |entry|
            if entry.is_a?(Hash)
              question = entry[:question] || entry['question'] || entry[:key] || entry['key'] || 'Question'
              answer = entry[:answer] || entry['answer'] || entry[:value] || entry['value'] || ''
              "  - #{question}: #{answer}"
            else
              "  - #{entry}"
            end
          end
          lines.join("\n").presence || "  - No checklist answers recorded."
        else
          "  - #{answers}"
        end
      end

      # ─── Weekly report placeholder substitution ────────────────────

      def substitute_weekly_placeholders(template, intent, payload)
        result = template.dup

        case intent.to_s
        when 'weekly_weather'
          result.gsub!('{{temp_high}}', payload[:temp_high].to_s)
          result.gsub!('{{temp_low}}', payload[:temp_low].to_s)
          result.gsub!('{{temp_avg}}', payload[:temp_avg].to_s)
          result.gsub!('{{wind_avg}}', payload[:wind_avg].to_s)
          result.gsub!('{{wind_max}}', payload[:wind_max].to_s)
          result.gsub!('{{precip_total}}', payload[:precip_total].to_s)
          result.gsub!('{{report_count}}', payload[:report_count].to_s)
          events = payload[:notable_events]
          result.gsub!('{{notable_events}}', events.is_a?(Array) ? events.join('; ') : events.to_s)

        when 'weekly_work_summary', 'weekly_work_summary_map'
          categories = payload[:categories]
          result.gsub!('{{categories}}', categories.is_a?(Array) ? categories.join(', ') : categories.to_s)
          entries = payload[:daily_entries]
          if entries.is_a?(Array)
            formatted = entries.map do |e|
              parts = ["Date: #{e[:date]}"]
              parts << "Commentary: #{e[:summary]}" if e[:summary].present?
              parts << "Additional Activities: #{e[:additional_activities]}" if e[:additional_activities].present?
              parts << "Additional Info: #{e[:additional_info]}" if e[:additional_info].present?
              parts.join("\n")
            end.join("\n---\n")
            result.gsub!('{{daily_entries}}', formatted)
          else
            result.gsub!('{{daily_entries}}', 'No daily entries available.')
          end

        when 'weekly_lab_testing'
          entries = payload
          if entries.is_a?(Array) && entries.any?
            # Group entries by test category for clearer AI input
            grouped = entries.group_by { |e| e[:test_category] || e[:test_type] }
            formatted = grouped.map do |category, cat_entries|
              lines = ["[#{category}] (#{cat_entries.size} test(s))"]
              pass_count = cat_entries.count { |e| e[:result].to_s == 'qa_pass' }
              fail_count = cat_entries.count { |e| e[:result].to_s == 'qa_fail' }
              pending_count = cat_entries.count { |e| e[:result].to_s == 'qa_pending' }
              lines << "  Pass: #{pass_count}, Fail: #{fail_count}#{pending_count > 0 ? ", Pending: #{pending_count}" : ''}"
              # Include details only for failures or notable entries
              cat_entries.select { |e| e[:result].to_s == 'qa_fail' }.each do |e|
                lines << "  - FAIL: #{e[:date]} at #{e[:location]}. #{e[:remarks]}"
              end
              # Summarize passing entries with just locations
              pass_locations = cat_entries.select { |e| e[:result].to_s == 'qa_pass' }.map { |e| e[:location] }.compact.uniq
              lines << "  - Pass locations: #{pass_locations.join(', ')}" if pass_locations.any?
              lines.join("\n")
            end.join("\n\n")
            result.gsub!('{{qa_entries}}', formatted)
          else
            result.gsub!('{{qa_entries}}', 'No QA entries recorded during this period.')
          end

        when 'weekly_materials'
          entries = payload
          if entries.is_a?(Array) && entries.any?
            formatted = entries.map do |e|
              "- #{e[:date]}: #{e[:test_type]} at #{e[:location]} — Result: #{e[:result]}. #{e[:remarks]}"
            end.join("\n")
            result.gsub!('{{failed_qa_entries}}', formatted)
          else
            result.gsub!('{{failed_qa_entries}}', 'No failed or out-of-tolerance QA entries during this period.')
          end

        when 'weekly_problem_areas'
          deficiencies = payload[:deficiencies]
          if deficiencies.is_a?(Array) && deficiencies.any?
            formatted = deficiencies.map do |d|
              "- #{d[:date]}: [#{d[:status]}] #{d[:description]}"
            end.join("\n")
            result.gsub!('{{deficiencies}}', formatted)
          else
            result.gsub!('{{deficiencies}}', 'No deficiencies reported during this period.')
          end

          safety = payload[:safety_issues]
          if safety.is_a?(Array) && safety.any?
            formatted = safety.map do |s|
              "- #{s[:date]}: #{s[:description]}"
            end.join("\n")
            result.gsub!('{{safety_issues}}', formatted)
          else
            result.gsub!('{{safety_issues}}', 'No safety incidents reported during this period.')
          end
        end

        result
      end
    end
  end
end
