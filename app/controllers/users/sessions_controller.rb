class Users::SessionsController < Devise::SessionsController
  def connect
    require 'slack-notifier'
    @encrypt = AesEncryptDecrypt.ssoencrypt("bis")
    @decrypt = AesEncryptDecrypt.ssodecrypt(params[:string])

    # test format
    if regex?

        sign_out(current_user)
        parsing_of_decrypt(@decrypt, @size_of_contract_num)
        # binding.pry
        if only_one_contract_on_apartment?
          sign_in(User.find(@user_id))
        else
          if new_user_but_a_contract_exists?
            create_a_new_user
          else
            create_a_new_user
          end
        end
        @email = @email
    end
    redirect_to root_path
  end

  private
    def regex?

      if @decrypt =~ /^\d\d\d\d\d\dH\d\d\d\d-\d\d\d\d\d\d-/
        @size_of_contract_num = 6
        return true
      else
        if @decrypt =~ /^\d\d\d\d\d\dH\d\d\d\d-\d\d\d\d\d-/
          @size_of_contract_num = 5
          return true
        else
          return false
        end
      end
    end

    def parsing_of_decrypt(decrypt, size_of_contract_num)
      # esi
      @esi = decrypt[0..5].to_i
      # apartment number
      @apartment_number = decrypt[7..10]
      # n° contrat
      @contract =  decrypt[12..12+size_of_contract_num-1]
      # email
      @email = decrypt[12+size_of_contract_num+1..-1]
    end

    def only_one_contract_on_apartment?
      if User.where(esi: @esi, apartment: @apartment_number, contract: @contract)[0] != nil
        @user_id = User.where(esi: @esi, apartment: @apartment_number, contract: @contract)[0][:id]
        return true
      else
        return false
      end
    end

    def new_user_but_a_contract_exists?
      if User.where(esi: @esi, apartment: @apartment_number)[0] != nil
        @other_user_id = User.where(esi: @esi, apartment: @apartment_number)[0][:id]
        User.find(@other_user_id).destroy
        return true
      else
        return false
      end
    end

    def create_a_new_user
      notifier = Slack::Notifier.new Rails.application.secrets.slack_key do
        defaults channel: "#rivp",
                 username: "Ton ami le serveur :)"
      end

      user = User.create!(username: "esi n°#{@esi} appart n° #{@apartment_number}",
        email: @email,
        password: Rails.application.secrets.user_pw,
        password_confirmation: Rails.application.secrets.user_pw,
        confirmed_at: Time.current,
        terms_of_service: "1",
        esi: @esi,
        contract: @contract,
        apartment: @apartment_number
        )
      if user.save
        user.update(verified_at: Time.current)
        user_id = User.last.id


        current_user_geozone = Geozone.where(census_code: @esi)
        user_heading_id = current_user_geozone[0][:external_code]
        site = Budget.last.groups.last.headings.find(user_heading_id)


        notifier.ping ":bust_in_silhouette: New user ! :bust_in_silhouette: #{site[:name]} - esi n°#{@esi} #{Geozone.where(census_code: @esi)[0].name} - appart n° #{@apartment_number} #{@email}"
        sign_in(User.find(user_id))
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
