class AddSsoFieldsAndAdminRoleToUsers < ActiveRecord::Migration[7.1]
  def change
    # SSO identity columns
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :oid, :string              # immutable Entra object ID (future-proofing)
    add_column :users, :preferred_username, :string # UPN from Entra (primary SSO key)

    # Allow SSO users to exist without a password
    change_column_null :users, :encrypted_password, true
    change_column_default :users, :encrypted_password, nil

    # Update role enum: inspector=0, qc=1, admin=2  (existing rows stay valid)
    # No column change needed — the integer column already supports new values.

    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
    add_index :users, :oid, unique: true, where: "oid IS NOT NULL"
  end
end
