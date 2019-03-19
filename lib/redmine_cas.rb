require 'casclient'
require 'casclient/frameworks/rails/filter'

module RedmineCAS
  extend self

  def setting(name)
    Setting.plugin_redmine_cas[name]
  end

  def enabled?
    setting(:enabled)
  end

  def autocreate_users?
    setting(:autocreate_users)
  end

  #
  # https://stackoverflow.com/questions/47397496/redmine-cas-plugin-missing-cas-base-url-parameter
  #
  # Seems that there was an old installation of the plugin in the database but not in the plugins folder. 
  # The data was still there but wasn't the expected and that was generating the issue.
  #   --- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
  #    enabled: 'false'
  #    cas_base_url: https://mycas.com
  #    cas_logout: 'true'
  # I updated the data from database in the table settings, the row with name = plugin_redmine_cas to
  #  --- !ruby/hash-with-ivars:ActionController::Parameters
  #   elements:
  #     enabled: '1'
  #     cas_base_url: https:/mycas.com/
  #     attributes_mapping: ''
  #   ivars:
  #     :@permitted: false
  #
  def setup!
    return unless enabled?
    CASClient::Frameworks::Rails::Filter.configure(
      :cas_base_url => setting(:cas_url),
      :logger => Rails.logger,
      :enable_single_sign_out => single_sign_out_enabled?
    )
  end

  def single_sign_out_enabled?
    ActiveRecord::Base.connection.table_exists?(:sessions)
  end

  def user_extra_attributes_from_session(session)
    attrs = {}
    map = Rack::Utils.parse_nested_query setting(:attributes_mapping)
    extra_attributes = session[:cas_extra_attributes] || {}
    map.each_pair do |key_redmine, key_cas|
      value = extra_attributes[key_cas]
      if User.attribute_method?(key_redmine) && value
        attrs[key_redmine] = (value.is_a? Array) ? value.first : value
      end
    end
    attrs
  end
end
