module Api
  module V1
    class ProjectsController < Api::BaseController
      # GET /api/v1/projects
      def index
        projects = Project.order(:name).map do |p|
          {
            id: p.id,
            name: p.name,
            contract_number: p.contract_number,
            project_manager: p.project_manager,
            construction_manager: p.construction_manager,
            prime_contractor: p.prime_contractor,
            contract_days: p.contract_days,
            contract_start_date: p.contract_start_date
          }
        end
        render json: projects
      end

      # GET /api/v1/projects/:id
      def show
        project = Project.find(params[:id])
        render json: {
          id: project.id,
          name: project.name,
          contract_number: project.contract_number,
          project_manager: project.project_manager,
          construction_manager: project.construction_manager,
          prime_contractor: project.prime_contractor,
          contract_days: project.contract_days,
          contract_start_date: project.contract_start_date,
          phases: project.phases.order(:name).map { |ph| { id: ph.id, name: ph.name } },
          bid_items: project.bid_items.includes(:spec_item).order(:code).map { |bi|
            {
              id: bi.id,
              code: bi.code,
              description: bi.spec_item&.description,
              spec_item_id: bi.spec_item_id,
              unit: bi.unit,
              bid_quantity: bi.bid_quantity,
              has_checklist: bi.active_questions.any?
            }
          }
        }
      end

      # GET /api/v1/projects/:project_id/bid_items/:id/checklist
      def bid_item_checklist
        project = Project.find(params[:project_id])
        bid_item = project.bid_items.includes(:spec_item).find(params[:id])
        questions = bid_item.active_questions

        render json: {
          bid_item_id: bid_item.id,
          bid_item_code: bid_item.code,
          spec_item_id: bid_item.spec_item_id,
          spec_description: bid_item.spec_item&.description,
          questions: questions.map { |q|
            {
              id: q["id"],
              prompt: q["prompt"],
              kind: q["kind"],
              options: q["options"]
            }
          }
        }
      end
    end
  end
end
