# frozen_string_literal: true

module ListingsQuery
  class Search
    def self.call(current_user, params, query_object_override=nil)
      new(current_user, params, query_object_override).call
    end

    def initialize(current_user, params, query_object_override=nil)
      @params = params
      @type = params[:market] || params[:type] || "all"
      @current_user = current_user
      @type = if @type.present?
                @type.downcase.singularize
              else
                "listing"
              end
      @query_object = query_object_override
    end

    def call
      relation_for(query_object)
    end

    private

    def relation_for(query_object_instance)
      if query_object_instance.class == ListingsQuery::Base
        base_filters(query_object_instance).relation
      elsif query_object_instance.class == ListingsQuery::Advisor
        advisor_filters(query_object_instance).relation
      elsif query_object_instance.class == ListingsQuery::Cpa
        cpa_filters(query_object_instance).relation
      else
        raise ArgumentError, "ListingsQuery 'Class: #{query_object_instance.class}' does not exist"
      end
    end

    def query_object_for(type, current_user)
      case type
      when "listing"
        ListingsQuery::Base.new(current_user)
      when "advisor"
        ListingsQuery::Advisor.new(current_user)
      when "cpa"
        ListingsQuery::Cpa.new(current_user)
      when "all"
        ListingsQuery::Base.new(current_user)
      else
        raise ArgumentError, "ListingsQuery 'type: #{@type}' does not exist"
      end
    end

    def query_object
      @query_object ||= query_object_for(@type, @current_user)
    end

    # rubocop:disable Metrics/AbcSize

    def base_filters(query_object)
      query_object.near(@params[:location], @params[:distance]) if @params[:location].present?
      query_object.with_lat_lon(@params[:latitude], @params[:longitude], @params[:distance]) if lat_lon_present?

      # .nil? use for favorited_ids param was intentional, do not change to .blank?
      query_object.with_favorited(@params[:favorited_ids]) unless @params[:favorited_ids].nil?

      filter query_object, :interested_in,              :interest_options
      filter query_object, :with_published_date_after,  :published_date
      filter query_object, :with_listing_id,            :listing_id
      filter query_object, :with_delay,                 :days_listing_access_delayed
      filter query_object, :with_wizard_status,         :wizard_status
      filter query_object, :with_published,             :published
      filter query_object, :with_membership,            :membership
      filter query_object, :with_user_id,               :user_id
      filter query_object, :without_user_id,            :exclude_user_id

      filter query_object, :with_limit, :limit
      query_object
    end

    def advisor_filters(query_object)
      base_filters(query_object)
      filter_percent_fee(query_object)      
      filter query_object, :with_max_aum, :max_aum
      filter query_object, :with_min_aum, :min_aum
      filter query_object, :with_max_gdc, :max_gdc
      filter query_object, :with_min_gdc, :min_gdc
      filter query_object, :with_clearing_firm_options, :clearing_firm_options
      filter query_object, :with_broker_dealer,         :broker_dealer
      filter query_object, :with_advisor_id,            :advisor_id
      query_object
    end

    def cpa_filters(query_object)
      base_filters(query_object)
      filter_percent_fee(query_object)      
      filter query_object, :with_max_revenue, :max_revenue
      filter query_object, :with_min_revenue, :min_revenue
      filter query_object, :with_services_options,   :service_options
      filter query_object, :with_credential_options, :credential_options
      filter query_object, :with_cpa_id, :cpa_id
      query_object
    end

    def filter_percent_fee(query_object)
      min, max = @params[:percent_fee].split("-") if @params[:percent_fee].present?
      query_object.with_percent_fee_equal_to(min) if min && !max
      query_object.with_percent_fee_between(min, max) if min && max
      query_object
    end

    # rubocop:enable Metrics/AbcSize

    def filter(query_object, method_name, param_name)
      query_object.public_send method_name, @params[param_name] if @params[param_name].present?
    end

    def lat_lon_present?
      @params[:latitude].present? && @params[:longitude].present? && @params[:distance].present?
    end
  end
end