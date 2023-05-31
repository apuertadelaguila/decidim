# frozen_string_literal: true

require "active_support/concern"

module Decidim
  # Common logic to switch between locales.
  module LocaleSwitcher
    extend ActiveSupport::Concern

    included do
      around_action :switch_locale
      helper_method :current_locale, :available_locales, :default_locale

      # Sets the locale for the current session.
      # Saves current locale in a session variable in case some links are locale-orphaned
      # Returns nothing.
      def switch_locale(&)
        locale = detect_locale
        if available_locales.include?(locale)
          session[:user_locale] = locale
        else
          locale = default_locale
        end
        I18n.with_locale(locale, &)
      end

      # Adds the current locale to all the URLs generated by url_for so users
      # experience a consistent behaviour if they copy or share links.
      #
      # Returns a Hash.
      def default_url_options
        return {} if current_locale == default_locale.to_s

        { locale: current_locale }
      end

      # The current locale for the user. Available as a helper for the views.
      #
      # Returns a String.
      def current_locale
        @current_locale ||= I18n.locale.to_s
      end

      # The available locales in the application. Available as a helper for the
      # views.
      #
      # Returns an Array of Strings.
      def available_locales
        @available_locales ||= (current_organization || Decidim).public_send(:available_locales)
      end

      # The default locale of this organization.
      #
      # Returns a String with the default locale.
      def default_locale
        @default_locale ||= (current_organization || Decidim).public_send(:default_locale)
      end

      # Detects the locale priority: query string, user saved, session, browser
      def detect_locale
        if params[:locale].present?
          params[:locale]
        elsif current_user && current_user.locale.present?
          current_user.locale
        elsif session[:user_locale].present?
          session[:user_locale]
        else
          extract_locale_from_accept_language_header
        end
      end

      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity

      # Finds a suitable language or returns nil
      # Follows the RFC 2616 rules with this particularities:
      # if no language matches, goes for the 2 chars prefixes
      # i.e.: pt-BR is available locale but user requests pt, then pt-BR will be served
      #     pt is available locale but user requests pt-BR, then pt will be served
      def extract_locale_from_accept_language_header
        return nil unless request.env["HTTP_ACCEPT_LANGUAGE"]

        accept_langs = request.env["HTTP_ACCEPT_LANGUAGE"].gsub(/[^a-z0-9\-;,=.]/i, "")

        langs_and_qs = accept_langs.split(",").each_with_index.map do |l, i|
          l += ";q=1.0" unless l =~ /;q=\d+(?:\.\d+)?$/
          parts = l.split(";q=")
          [parts[0], parts[1].to_f - (i.to_f / 1000)]
        end
        langs_and_qs = langs_and_qs.sort_by { |(_l, q)| q }.reverse
        lang = langs_and_qs.detect do |(locale, _q)|
          locale == "*" || available_locales.map(&:to_s).include?(locale.to_s)
        end

        lang &&= lang.first
        # if no language detected go for RFC 2616 non-compliant (check prefixes)
        lang ||= available_locales.detect do |available|
          langs_and_qs.any? { |locale, _q| locale.to_s[0..1] == available.to_s[0..1] }
        end
        lang == "*" ? nil : lang
      end
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity
    end
  end
end
