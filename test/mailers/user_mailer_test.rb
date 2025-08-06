require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "email_verification" do
    user = users(:one) # Assuming you have a fixture
    verification_token = user.email_verification_tokens.create!(
      token: "test_token_123",
      expires_at: 24.hours.from_now
    )
    
    email = UserMailer.email_verification(user, verification_token)
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ['from@example.com'], email.from
    assert_equal [user.email], email.to
    assert_equal 'Please verify your email address', email.subject
    assert_match verification_token.token, email.body.to_s
  end
end
