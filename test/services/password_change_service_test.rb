require 'test_helper'

class PasswordChangeServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one) # Assuming you have fixtures
    @user.update(password: 'OldPassword123')
  end

  test 'successfully changes password with valid data' do
    result = PasswordChangeService.call(
      user: @user,
      current_password: 'OldPassword123',
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert result.success?
    assert @user.reload.authenticate('NewPassword456')
    assert_not @user.authenticate('OldPassword123')
  end

  test 'fails when current password is incorrect' do
    result = PasswordChangeService.call(
      user: @user,
      current_password: 'WrongPassword',
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert_not result.success?
    assert_includes result.errors, 'Current password is incorrect'
  end

  test 'fails when new password and confirmation do not match' do
    result = PasswordChangeService.call(
      user: @user,
      current_password: 'OldPassword123',
      new_password: 'NewPassword456',
      new_password_confirmation: 'DifferentPassword'
    )

    assert_not result.success?
    assert_includes result.errors, 'New password and confirmation do not match'
  end

  test 'fails when new password is same as current password' do
    result = PasswordChangeService.call(
      user: @user,
      current_password: 'OldPassword123',
      new_password: 'OldPassword123',
      new_password_confirmation: 'OldPassword123'
    )

    assert_not result.success?
    assert_includes result.errors, 'New password must be different from current password'
  end

  test 'fails when new password is too weak' do
    result = PasswordChangeService.call(
      user: @user,
      current_password: 'OldPassword123',
      new_password: 'weak',
      new_password_confirmation: 'weak'
    )

    assert_not result.success?
    assert_includes result.errors, 'New password must be at least 8 characters long'
  end

  test 'fails when required parameters are missing' do
    result = PasswordChangeService.call(
      user: @user,
      current_password: '',
      new_password: 'NewPassword456',
      new_password_confirmation: 'NewPassword456'
    )

    assert_not result.success?
    assert_includes result.errors, 'Current password is required'
  end
end
