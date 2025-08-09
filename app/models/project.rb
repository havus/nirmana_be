class Project < ApplicationRecord
  belongs_to :user

  enum :visibility, { personal: 0, shared: 1 }, default: :personal

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :version, presence: true, length: { maximum: 10 }
  validates :board_config, presence: true
  validates :nails, presence: true

  # Callbacks
  before_validation :set_default_version, on: :create

  # Scopes
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def dots_count_horizontal
    board_config&.dig('dotsCountHorizontal')
  end

  def dots_count_vertical
    board_config&.dig('dotsCountVertical')
  end

  def margin_between_nails
    board_config&.dig('marginBetweenNails')
  end

  def padding_board
    board_config&.dig('paddingBoard')
  end

  def board_color
    board_config&.dig('boardColor')
  end

  def nail_count
    nails&.keys&.count || 0
  end

  private

  def set_default_version
    self.version ||= '1.0.0'
  end
end
