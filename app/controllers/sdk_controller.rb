class SdkController < ApplicationController
  # Remova ou modifique a linha skip_before_action :authenticate_user!
  # Por exemplo, se o controlador realmente não precisa de autenticação:
  # skip_before_action :authenticate_user!, if: -> { respond_to?(:authenticate_user!) }
  skip_before_action :verify_authenticity_token

  def index
    response.headers['Content-Type'] = 'application/javascript'
    render file: "#{Rails.root}/public/packs/js/sdk.js", layout: false
  end
end
