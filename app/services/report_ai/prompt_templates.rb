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

    COMMENTARY_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that expands inspection commentary into detailed, professional narratives for construction daily reports.

      Your output should:
      - Elaborate on the inspector's original commentary with more detail
      - Integrate information from checklists, QA entries, and compliance items
      - Maintain a professional, factual tone
      - Be 2-5 paragraphs
      - Include specific details about work performed, locations, and any issues noted
      - Reference compliance items and any concerns
      - NOT contradict or misrepresent the original inspector commentary

      example 1:
      input:surface was clean before tack, nozzles clean, correct rate
      output:Prior to paving the surface was cleaned of dust and debris using a street sweeper,
      a vacuum truck and leaf blowers before applying a P-603 tack coat,
      in accordance with FAA specifications. I confirmed that the nozzles on the tack truck were clean 
      and operating properly, and that tack coat was applied at the correct rate per the plans and FAA specs.

      example 2:
      input:Crew used survey sticks to check grade during paving
      output:Granite used survey equipment to conduct grade checks
      throughout the paving operation. 

      example 3:
      input:No issues with compaction.
      output:The mat was compacted immediately after placement. using a HAMM 120i breakdown roller,
      HAMM 110i wheel roller and a Sakai 8-wheel pneumatic roller as intermediate rollers,
      as well as a CAT CB10 finishing roller. Compaction efforts were completed before 
      mat temperature dropped below 160 degrees. The rollers were equipped with misting systems
      to prevent asphalt pickup on the drums. No displacement or surface distortion of the asphalt was observed 
      during compaction operations.
    PROMPT

    COMMENTARY_USER_PROMPT = <<~PROMPT
      Based on the following daily inspection report data, generate an expanded commentary.

      Report Date: {{start_date}}
      Project: {{project_name}}
      Phase: {{phase_name}}

      Original Inspector Commentary:
      {{commentary}}

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

      Generate an expanded professional commentary that incorporates these details while maintaining the inspector's original intent and observations.
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
      - Use category headings EXACTLY as provided in "Work Categories" (do not rename, merge, or invent categories)
      - Under each heading, write bullet points (using "- " prefix) summarizing what work was performed
      - Each bullet is 1–2 sentences maximum — no multi-sentence paragraphs
      - Limit to 3–6 bullets per category; combine minor related activities into one bullet
      - For categories with no activity this period, write a single bullet: "No [category] work was performed this period."
      - Focus on measurable quantities, locations, and methods when data provides them
      - Professional, technical tone suitable for official FAA documentation
      - Do NOT repeat identical information across categories
      - Do NOT add an introduction, conclusion, or overall summary paragraph
      - Total output length: aim for 150–400 words across all categories

      CONTENT RULES (match FAA weekly style):
      - Aim for the detail level shown in the GOOD examples: include approximate quantities and general location extents when available.
      - Do NOT include QA/QC or test-result minutiae in Section 4. Testing belongs in Section 5.
      - Specifically OMIT: individual test readings (density %, temperatures, slump/air, megohm readings), acceptance statements ("passed", "met spec") unless it caused a delay/issue, survey tolerances (± values), cable pulling tensions, conduit depth verifications, record drawing/as-built updates, submittals/approvals, and administrative inventory notes.
      - If the input contains those details, either omit them or restate at a higher level (e.g., "testing performed" without numbers) only when necessary for context.

      GOOD (appropriate detail):
      - "Airfield crews continued coring and trenching for new taxiway light circuits, installing approximately 543 LF of conduit and 11 base cans."

      BAD (too detailed; do not do this):
      - "Cable pulling began 0800; maximum tension 600 lbs; terminations documented with mega-ohm readings; conduit depth verified minimum 24 inches..."
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

      Generate a professional work summary following this exact format, grouped by the categories listed above. Use the category headings exactly as provided.
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
      - Omit QA/QC and test-result minutiae (individual readings, pass/fail statements, tolerances, megohm readings, survey/as-built notes)
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
          substitute_placeholders(template, payload)
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
