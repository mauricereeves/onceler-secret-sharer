class CreateAccessLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :access_logs do |t|
      t.references :secret, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.string :action # 'viewed', 'failed_attempt', 'created'
      t.text :details
      t.datetime :accessed_at

      t.timestamps
    end

    add_index :access_logs, :accessed_at
    add_index :access_logs, [ :secret_id, :action ]
  end
end
