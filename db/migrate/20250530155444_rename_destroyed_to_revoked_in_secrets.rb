class RenameDestroyedToRevokedInSecrets < ActiveRecord::Migration[8.0]
  def change
    rename_column :secrets, :destroyed, :revoked
  end
end
