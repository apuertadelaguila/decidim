# frozen_string_literal: true

module Decidim
  module Initiatives
    require "wicked"

    class InitiativeSignaturesController < Decidim::Initiatives::ApplicationController
      # layout "layouts/decidim/initiative_signature_creation"

      # include Wicked::Wizard
      include Decidim::Initiatives::NeedsInitiative
      include Decidim::FormFactory

      prepend_before_action :set_wizard_steps
      before_action :authenticate_user!
      before_action :enforce_permissions, only: [
        :show,
        :update,
        :fill_personal_data,
        :set_sms_phone_number,
        :sms_phone_number,
        :set_sms_code,
        :sms_code,
        :set_finish,
        :finish
      ]

      before_action :set_data, only: [:set_sms_phone_number, :set_finish]

      helper InitiativeHelper

      helper_method :initiative_type, :extra_data_legal_information, :wizard_steps

      def index
        if fill_personal_data_step?
          redirect_to fill_personal_data_initiative_initiative_signatures_path(current_initiative)
          return
        end

        if sms_step?
          redirect_to sms_phone_number_initiative_initiative_signatures_path(current_initiative) && return

        end
        redirect_to finish_initiative_initiative_signatures_path(current_initiative)
      end

      # POST /initiatives/:initiative_id/initiative_signatures
      def create
        enforce_permission_to :vote, :initiative, initiative: current_initiative

        @form = form(Decidim::Initiatives::VoteForm)
                .from_params(
                  initiative: current_initiative,
                  signer: current_user
                )

        VoteInitiative.call(@form) do
          on(:ok) do
            current_initiative.reload
            render :update_buttons_and_counters
          end

          on(:invalid) do
            render :error_on_vote, status: :unprocessable_entity
          end
        end
      end

      def set_fill_personal_data
        build_vote_form(params)

        if sms_step?
          redirect_to sms_phone_number_initiative_initiative_signatures_path(current_initiative)
        else
          redirect_to finish_initiative_initiative_signatures_path(current_initiative)
        end
        return
      end

      def fill_personal_data
        @form = form(Decidim::Initiatives::VoteForm)
                .from_params(
                  initiative: current_initiative,
                  signer: current_user
                )

        session[:initiative_vote_form] = {}
      end


      def sms_phone_number
        @form = Decidim::Verifications::Sms::MobilePhoneForm.new
      end

      def set_sms_phone_number
        clear_session_sms_code

        if @vote_form.invalid?
          flash[:alert] = I18n.t("personal_data.invalid", scope: "decidim.initiatives.initiative_votes")

          redirect_to fill_personal_data_initiative_initiative_signatures_path(current_initiative) && return
        end

        @form = Decidim::Verifications::Sms::MobilePhoneForm.new
      end

      def set_sms_code
        check_session_personal_data if fill_personal_data_step?
        @phone_form = Decidim::Verifications::Sms::MobilePhoneForm.from_params(params.merge(user: current_user))
        @form = Decidim::Verifications::Sms::ConfirmationForm.new
        render_wizard && return if session_sms_code.present?

        ValidateMobilePhone.call(@phone_form, current_user) do
          on(:ok) do |metadata|
            store_session_sms_code(metadata)
            render_wizard
          end

          on(:invalid) do
            flash[:alert] = I18n.t("sms_phone.invalid", scope: "decidim.initiatives.initiative_votes")
            redirect_to wizard_path(:sms_phone_number)
          end
        end
      end

      def sms_code
        check_session_personal_data if fill_personal_data_step?
        @phone_form = Decidim::Verifications::Sms::MobilePhoneForm.from_params({ initiative_vote_form: session[:initiative_vote_form], user: current_user })
        @form = Decidim::Verifications::Sms::ConfirmationForm.new
        render_wizard && return if session_sms_code.present?
      end


      def set_finish

        if sms_step?
          @confirmation_code_form = Decidim::Verifications::Sms::ConfirmationForm.from_params(params)

          ValidateSmsCode.call(@confirmation_code_form, session_sms_code) do
            on(:ok) { clear_session_sms_code }

            on(:invalid) do
              flash[:alert] = I18n.t("sms_code.invalid", scope: "decidim.initiatives.initiative_votes")
              jump_to :sms_code
              render_wizard && return
            end
          end
        end

        VoteInitiative.call(@vote_form) do
          on(:ok) do
            session[:initiative_vote_form] = {}
          end

          on(:invalid) do |vote|
            logger.fatal "Failed creating signature: #{vote.errors.full_messages.join(", ")}" if vote
            flash[:alert] = I18n.t("create.invalid", scope: "decidim.initiatives.initiative_votes")
            jump_to previous_step
          end
        end

        render_wizard
      end

      def finish
        render_wizard
      end

      private

      def enforce_permissions
        enforce_permission_to :sign_initiative, :initiative, initiative: current_initiative, signature_has_steps: signature_has_steps?
      end

      def build_vote_form(parameters)
        @vote_form = form(Decidim::Initiatives::VoteForm).from_params(parameters).tap do |form|
          form.initiative = current_initiative
          form.signer = current_user
        end

        session[:initiative_vote_form] ||= {}
        session[:initiative_vote_form] = session[:initiative_vote_form].merge(@vote_form.attributes_with_values.except(:initiative, :signer))
      end

      def session_vote_form
        attributes = session[:initiative_vote_form].merge(initiative: current_initiative, signer: current_user)

        @vote_form = form(Decidim::Initiatives::VoteForm).from_params(attributes)
      end

      def initiative_type
        @initiative_type ||= current_initiative&.scoped_type&.type
      end

      def extra_data_legal_information
        @extra_data_legal_information ||= initiative_type.extra_fields_legal_information
      end

      def check_session_personal_data
        return if session[:initiative_vote_form].present? && session_vote_form&.valid?

        raise session_vote_form.valid?.inspect
        flash[:alert] = I18n.t("create.error", scope: "decidim.initiatives.initiative_votes")
        redirect_to fill_personal_data_initiative_initiative_signatures_path(current_initiative)
        return
      end

      def store_session_sms_code(metadata)
        session[:initiative_sms_code] = metadata
      end

      def session_sms_code
        session[:initiative_sms_code]
      end

      def clear_session_sms_code
        session[:initiative_sms_code] = {}
      end

      def sms_step?
        current_initiative.validate_sms_code_on_votes?
      end

      def fill_personal_data_step?
        initiative_type.collect_user_extra_fields?
      end

      def set_wizard_steps
        initial_wizard_steps = [:finish]
        initial_wizard_steps.unshift(:sms_phone_number, :sms_code) if sms_step?
        initial_wizard_steps.unshift(:fill_personal_data) if fill_personal_data_step?

        @steps = initial_wizard_steps
      end
      # ============================

      def wizard_steps
        @steps
      end

      def set_data
        if params.has_key?(:initiatives_vote) || !fill_personal_data_step?
          build_vote_form(params)
        else
          check_session_personal_data
        end
      end
    end
  end
end
