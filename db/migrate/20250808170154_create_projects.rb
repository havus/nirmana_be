class CreateProjects < ActiveRecord::Migration[8.0]
  def up
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, limit: 255
      t.string :version, default: '1.0.0', limit: 10
      t.integer :visibility, default: 0, null: false

      # Separate JSONB columns for better organization
      t.jsonb :board_config, null: false  # dimensions, appearance, etc.
      t.jsonb :nails, null: false         # position-based nail data {"x,y": {...}}

      t.timestamps
    end
  end

  def down
    drop_table :projects
  end
end
