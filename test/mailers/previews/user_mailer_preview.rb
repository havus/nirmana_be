# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def email_verification
    user = User.new(
      email: "john.doe@example.com",
      first_name: "John",
      last_name: "Doe"
    )

    verification_token = EmailVerificationToken.new(
      token: "sample_verification_token_123",
      expires_at: 24.hours.from_now
    )

    UserMailer.email_verification(user, verification_token)
  end

  def password_reset
    user = User.new(
      email: "john.doe@example.com",
      first_name: "John",
      last_name: "Doe"
    )

    reset_token = PasswordResetToken.new(
      token: "sample_reset_token_123",
      expires_at: 24.hours.from_now
    )

    UserMailer.password_reset(user, reset_token)
  end
end
