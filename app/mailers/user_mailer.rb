class UserMailer < ApplicationMailer
  def email_verification(user, verification_token)
    @user = user
    @verification_token = verification_token
    @verification_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/verify-email?token=#{@verification_token.token}"

    mail(
      to: @user.email,
      subject: 'Please verify your email address'
    )
  end
end
