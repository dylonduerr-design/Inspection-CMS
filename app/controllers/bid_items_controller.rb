class BidItemsController < ApplicationController
  before_action :set_project
  before_action :set_bid_item, only: %i[ show edit update destroy ]

  # GET /projects/1/bid_items → redirect to project show with bid-items tab
  def index
    redirect_to project_path(@project, anchor: "bid-items")
  end

  # GET /projects/1/bid_items/new
  def new
    @bid_item = @project.bid_items.build
  end

  # POST /projects/1/bid_items
  def create
    @bid_item = @project.bid_items.build(bid_item_params)

    if @bid_item.save
      redirect_to project_path(@project, anchor: "bid-items"), notice: "Bid item added to library."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /projects/1/bid_items/1/edit
  def edit
  end

  # PATCH /projects/1/bid_items/1
  def update
    if @bid_item.update(bid_item_params)
      redirect_to project_path(@project, anchor: "bid-items"), notice: "Bid item updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bid_item.destroy
    redirect_to project_path(@project, anchor: "bid-items"), notice: "Bid item removed."
  end

  private
    def set_project
      @project = Project.find(params[:project_id])
    end

    def set_bid_item
      @bid_item = @project.bid_items.find(params[:id])
    end

    def bid_item_params
      # We now require the spec_item_id as well
      params.require(:bid_item).permit(:code, :description, :unit, :spec_item_id, :questions_text, :bid_quantity, :sov_category)
    end
end