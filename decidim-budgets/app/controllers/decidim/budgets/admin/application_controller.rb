# frozen_string_literal: true

module Decidim
  module Budgets
    module Admin
      # This controller is the abstract class from which all other controllers of
      # this engine inherit.
      #
      # Note that it inherits from `Decidim::Components::BaseController`, which
      # override its layout and provide all kinds of useful methods.
      class ApplicationController < Decidim::Admin::Components::BaseController
        helper_method :budget, :projects, :project

        def budget
          @budget ||= Budget.where(component: current_component).includes(:projects).find_by(id: params[:budget_id])
        end

        def projects
          @projects ||= if budget
                          budget.projects
                        else
                          Decidim::Budgets::Project.joins(:budget).where(budget: { component: current_component })
                        end
        end

        def project
          @project ||= projects.find(params[:project_id] || params[:id])
        end
      end
    end
  end
end
