class CreateSecrets < ActiveRecord::Migration[8.0]
  def change
    create_table :secrets do |t|
      t.string :token, null: false, index: { unique: true }
      t.text :encrypted_content
      t.string :content_iv
      t.datetime :expires_at
      t.string :created_by_ip
      t.integer :max_views, default: 1
      t.integer :view_count, default: 0
      t.boolean :destroyed, default: false

      t.timestamps
    end

    add_index :secrets, :expires_at
  end
end
