require 'test_helper'

class ResetPasswordServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one) # Assuming you have fixtures
    @user.update(password: 'OldPassword123')
    @reset_token = PasswordResetToken.create_for_user(@user)
  end

  test 'successfully resets password with valid token' do
    result = ResetPasswordService.call(
      token: @reset_token.token,
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert result.success?
    assert @user.reload.authenticate('NewPassword456')
    assert_not @user.authenticate('OldPassword123')
    assert @reset_token.reload.used?
  end

  test 'fails with invalid token' do
    result = ResetPasswordService.call(
      token: 'invalid_token',
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert_not result.success?
    assert_includes result.errors, 'Invalid or expired reset token'
  end

  test 'fails with mismatched passwords' do
    result = ResetPasswordService.call(
      token: @reset_token.token,
      new_password: 'NewPassword456',
      new_password_confirmation: 'DifferentPassword'
    )

    assert_not result.success?
    assert_includes result.errors, 'New password and confirmation do not match'
  end

  test 'fails with weak password' do
    result = ResetPasswordService.call(
      token: @reset_token.token,
      new_password: 'weak',
      new_password_confirmation: 'weak'
    )

    assert_not result.success?
    assert_includes result.errors, 'New password must be at least 8 characters long'
  end

  test 'fails with used token' do
    @reset_token.use!

    result = ResetPasswordService.call(
      token: @reset_token.token,
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert_not result.success?
    assert_includes result.errors, 'Invalid or expired reset token'
  end

  test 'fails with expired token' do
    @reset_token.update!(expires_at: 1.hour.ago)

    result = ResetPasswordService.call(
      token: @reset_token.token,
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert_not result.success?
    assert_includes result.errors, 'Invalid or expired reset token'
  end

  test 'fails when required parameters are missing' do
    result = ResetPasswordService.call(
      token: '',
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert_not result.success?
    assert_includes result.errors, 'Token is required'
  end

  test 'invalidates all user sessions after password reset' do
    session1 = UserSession.create_for_user(@user)
    session2 = UserSession.create_for_user(@user)

    result = ResetPasswordService.call(
      token: @reset_token.token,
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert result.success?
    assert_nil UserSession.find_by(id: session1.id)
    assert_nil UserSession.find_by(id: session2.id)
  end
end
