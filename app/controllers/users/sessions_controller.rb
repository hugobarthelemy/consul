class Users::SessionsController < Devise::SessionsController
  def connect
    @encrypt = AesEncryptDecrypt.encrypt("bis")
    @decrypt = AesEncryptDecrypt.decrypt(params[:string])

    # test format
    if regex?
      @coucou = "hello world"

    end
  end

  private
    def regex?

      if @decrypt =~ /^\d\d\d\d\d\dH\d\d\d\d-\d\d\d\d\d\d$/
        return true
      else
        return false
      end
    end

    def after_sign_in_path_for(resource)
      if !verifying_via_email? && resource.show_welcome_screen?
        welcome_path
      else
        super
      end
    end

    def after_sign_out_path_for(resource)
      request.referrer.present? ? request.referrer : super
    end

    def verifying_via_email?
      return false unless resource.present?
      stored_path = session[stored_location_key_for(resource)] || ""
      stored_path[0..5] == "/email"
    end

end


