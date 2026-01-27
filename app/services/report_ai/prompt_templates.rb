# frozen_string_literal: true

module ReportAi
  # Prompt templates for AI generation
  class PromptTemplates
    WORK_SUMMARY_SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that produces concise, factual work summaries for construction inspection daily reports.

      Your output should be:
      - A bullet-point summary of the day's work activities
      - Focus on: what work was done, quantities placed, locations, and any notable conditions
      - Professional, technical tone suitable for official documentation
      - Do NOT include weather details (that is a separate section)
      - Do NOT include opinions or subjective assessments
    PROMPT

    WORK_SUMMARY_USER_PROMPT = <<~PROMPT
      Based on the following daily inspection report data, generate a concise work summary.

      Report Date: {{start_date}}
      Project: {{project_name}}
      Phase: {{phase_name}}
      Inspector: {{inspector_email}}

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
        else
          raise ArgumentError, "Unknown intent: #{intent}"
        end
      end

      def render_user_prompt(intent:, payload:)
        template = for_intent(intent)[:user]
        substitute_placeholders(template, payload)
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
          answers = checklist[:answers]&.map { |a| "  - #{a[:question]}: #{a[:answer]}" }&.join("\n")
          "#{checklist[:spec_code]}: #{checklist[:spec_description]}\n#{answers}"
        end.join("\n\n")
      end

      def format_bid_item_checklists(bid_items)
        items_with_checklists = bid_items&.select { |i| i[:checklist_answers].present? }
        return "No bid item checklists recorded." if items_with_checklists.blank?
        
        items_with_checklists.map do |item|
          answers = item[:checklist_answers]&.map { |a| "  - #{a[:question]}: #{a[:answer]}" }&.join("\n")
          "#{item[:code]}: #{item[:description]}\n#{answers}"
        end.join("\n\n")
      end
    end
  end
end
