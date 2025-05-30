# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_05_30_013202) do
  create_table "access_logs", force: :cascade do |t|
    t.integer "secret_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "action"
    t.text "details"
    t.datetime "accessed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accessed_at"], name: "index_access_logs_on_accessed_at"
    t.index ["secret_id", "action"], name: "index_access_logs_on_secret_id_and_action"
    t.index ["secret_id"], name: "index_access_logs_on_secret_id"
  end

  create_table "secrets", force: :cascade do |t|
    t.string "token", null: false
    t.text "encrypted_content"
    t.string "content_iv"
    t.datetime "expires_at"
    t.string "created_by_ip"
    t.integer "max_views", default: 1
    t.integer "view_count", default: 0
    t.boolean "destroyed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_secrets_on_expires_at"
    t.index ["token"], name: "index_secrets_on_token", unique: true
  end

  add_foreign_key "access_logs", "secrets"
end
