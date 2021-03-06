module Budgets
  class InvestmentsController < ApplicationController
    include FeatureFlags
    include CommentableActions
    include FlagActions

    before_action :authenticate_user!, except: [:index, :show]

    load_and_authorize_resource :budget
    load_and_authorize_resource :investment, through: :budget, class: "Budget::Investment"

    before_action -> { flash.now[:notice] = flash[:notice].html_safe if flash[:html_safe] && flash[:notice] }
    before_action :load_ballot, only: [:index, :show]
    before_action :load_heading, only: [:index, :show]
    before_action :set_random_seed, only: :index
    before_action :load_categories, only: [:index, :new, :create]

    feature_flag :budgets

    has_orders %w{most_voted newest oldest}, only: :show
    has_orders ->(c) { c.instance_variable_get(:@budget).investments_orders }, only: :index

    invisible_captcha only: [:create, :update], honeypot: :subtitle, scope: :budget_investment

    respond_to :html, :js

    def index
      @investments = @investments.apply_filters_and_search(@budget, params).send("sort_by_#{@current_order}").page(params[:page]).per(10).for_render
      @investment_ids = @investments.pluck(:id)
      load_investment_votes(@investments)
      @tag_cloud = tag_cloud
    end

    def new
      @method = :post
    end

    def show
      @commentable = @investment
      @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
      set_comment_flags(@comment_tree.comments)
      load_investment_votes(@investment)
      @investment_ids = [@investment.id]
    end

    def create
      @investment.author = current_user

      if @investment.save
        notifier = Slack::Notifier.new Rails.application.secrets.slack_key do
          defaults channel: "#rivp",
                   username: "Ton ami le serveur :)"
        end

        notifier.ping ":champagne: New investment ! :champagne: #{@investment[:title]} - #{@investment[:description]} - site : #{Budget.last.groups.last.headings.find(params[:budget_investment][:heading_id])[:name]}"
        Mailer.budget_investment_created(@investment).deliver_later
        redirect_to budget_investment_path(@budget, @investment),
                    notice: t('flash.actions.create.budget_investment')
      else
        render :new
      end
    end

    def edit
      @method = :patch
    end

    def update
      @investment = Budget::Investment.find(params[:id])
      if @investment.update(title: params[:budget_investment][:title],
        description: params[:budget_investment][:description],
        external_url: params[:budget_investment][:external_url],
        location: params[:budget_investment][:location],
        organization_name: params[:budget_investment][:organization_name],
        tag_list: params[:budget_investment][:tag_list])

        notifier = Slack::Notifier.new Rails.application.secrets.slack_key do
          defaults channel: "#rivp",
                   username: "Ton ami le serveur :)"
        end

        notifier.ping ":champagne: Investment update ! :champagne: #{@investment[:title]} - #{@investment[:description]} - site : #{Budget.last.groups.last.headings.find(params[:budget_investment][:heading_id])[:name]}"
        Mailer.budget_investment_created(@investment).deliver_later
        redirect_to budget_investment_path(@budget, @investment),
                    notice: t('flash.actions.create.budget_investment')
      else
        render :edit
      end
    end

    def destroy
      investment.destroy
      redirect_to user_path(current_user, filter: 'budget_investments'), notice: t('flash.actions.destroy.budget_investment')
    end

    def vote
      @investment.register_selection(current_user)
      load_investment_votes(@investment)
      respond_to do |format|
        format.html { redirect_to budget_investments_path(heading_id: @investment.heading.id) }
        format.js
      end
    end

    private

      def load_investment_votes(investments)
        @investment_votes = current_user ? current_user.budget_investment_votes(investments) : {}
      end

      def set_random_seed
        if params[:order] == 'random' || params[:order].blank?
          params[:random_seed] ||= rand(99)/100.0
          Budget::Investment.connection.execute "select setseed(#{params[:random_seed]})"
        else
          params[:random_seed] = nil
        end
      end

      def investment_params
        params.require(:budget_investment).permit(:title, :description, :external_url, :heading_id, :tag_list, :organization_name, :location, :terms_of_service)
      end

      def load_ballot
        query = Budget::Ballot.where(user: current_user, budget: @budget)
        @ballot = @budget.balloting? ? query.first_or_create : query.first_or_initialize
      end

      def load_heading
        if params[:heading_id].present?
          @heading = @budget.headings.find(params[:heading_id])
          @assigned_heading = @ballot.try(:heading_for_group, @heading.try(:group))
        end
      end

      def load_categories
        @categories = ActsAsTaggableOn::Tag.where("kind = 'category'").order(:name)
      end

      def tag_cloud
        TagCloud.new(Budget::Investment, params[:search])
      end
  end

end
