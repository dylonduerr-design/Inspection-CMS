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

ActiveRecord::Schema[7.1].define(version: 2026_03_20_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.bigint "user_id", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_activity_logs_on_report_id"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "approved_equipments", force: :cascade do |t|
    t.string "name"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.index ["project_id"], name: "index_approved_equipments_on_project_id"
  end

  create_table "bid_items", force: :cascade do |t|
    t.string "code"
    t.string "description"
    t.string "unit"
    t.jsonb "checklist_questions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "spec_item_id", null: false
    t.bigint "project_id"
    t.decimal "bid_quantity", precision: 15, scale: 3
    t.string "sov_category"
    t.string "trade_package"
    t.index ["project_id", "code"], name: "index_bid_items_on_project_id_and_code", unique: true
    t.index ["project_id"], name: "index_bid_items_on_project_id"
    t.index ["sov_category"], name: "index_bid_items_on_sov_category"
    t.index ["spec_item_id"], name: "index_bid_items_on_spec_item_id"
    t.index ["trade_package"], name: "index_bid_items_on_trade_package"
  end

  create_table "checklist_entries", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.bigint "spec_item_id", null: false
    t.jsonb "checklist_answers"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_checklist_entries_on_report_id"
    t.index ["spec_item_id"], name: "index_checklist_entries_on_spec_item_id"
  end

  create_table "crew_entries", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.string "contractor"
    t.integer "laborer_count"
    t.integer "operator_count"
    t.integer "survey_count"
    t.integer "electrician_count"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "foreman_count", default: 0
    t.integer "superintendent_count", default: 0
    t.index ["report_id"], name: "index_crew_entries_on_report_id"
  end

  create_table "equipment_entries", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.string "contractor"
    t.string "make_model"
    t.integer "quantity", default: 1
    t.decimal "hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "remarks"
    t.index ["report_id"], name: "index_equipment_entries_on_report_id"
  end

  create_table "imported_reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id"
    t.string "status", default: "imported", null: false
    t.string "contract_number"
    t.string "project_title"
    t.float "template_confidence"
    t.text "template_errors"
    t.jsonb "parsed_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_number"], name: "index_imported_reports_on_contract_number"
    t.index ["project_id"], name: "index_imported_reports_on_project_id"
    t.index ["status"], name: "index_imported_reports_on_status"
    t.index ["user_id"], name: "index_imported_reports_on_user_id"
  end

  create_table "phases", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "project_id", null: false
    t.index ["project_id"], name: "index_phases_on_project_id"
  end

  create_table "placed_quantities", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.bigint "bid_item_id", null: false
    t.decimal "quantity"
    t.text "notes"
    t.jsonb "checklist_answers", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location"
    t.index ["bid_item_id"], name: "index_placed_quantities_on_bid_item_id"
    t.index ["report_id"], name: "index_placed_quantities_on_report_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "contract_number"
    t.string "project_manager"
    t.string "construction_manager"
    t.integer "contract_days"
    t.date "contract_start_date"
    t.string "prime_contractor"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
  end

  create_table "qa_entries", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.integer "qa_type"
    t.string "location"
    t.integer "result"
    t.string "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_qa_entries_on_report_id"
  end

  create_table "report_attachments", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.string "caption"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_report_attachments_on_report_id"
  end

  create_table "report_exports", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "queued", null: false
    t.integer "progress", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_report_exports_on_report_id"
    t.index ["status"], name: "index_report_exports_on_status"
    t.index ["user_id"], name: "index_report_exports_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.string "dir_number"
    t.date "start_date"
    t.date "end_date"
    t.bigint "project_id"
    t.bigint "phase_id"
    t.bigint "user_id", null: false
    t.integer "status"
    t.integer "result"
    t.string "shift_start"
    t.string "shift_end"
    t.integer "temp_1"
    t.integer "temp_2"
    t.integer "temp_3"
    t.string "wind_1"
    t.string "wind_2"
    t.string "wind_3"
    t.string "precip_1"
    t.string "precip_2"
    t.string "precip_3"
    t.string "weather_summary_1"
    t.string "weather_summary_2"
    t.string "weather_summary_3"
    t.string "contractor"
    t.string "plan_sheet"
    t.string "relevant_docs"
    t.string "station_start"
    t.string "station_end"
    t.integer "deficiency_status"
    t.text "deficiency_desc"
    t.integer "traffic_control"
    t.integer "environmental"
    t.integer "security"
    t.integer "safety_incident"
    t.text "safety_desc"
    t.integer "air_ops_coordination", default: 0
    t.integer "swppp_controls", default: 0
    t.text "commentary"
    t.text "additional_activities"
    t.text "additional_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visibility_1"
    t.string "visibility_2"
    t.string "visibility_3"
    t.string "surface_conditions"
    t.integer "phasing_compliance", default: 0
    t.text "phasing_compliance_note"
    t.text "traffic_control_note"
    t.text "environmental_note"
    t.text "security_note"
    t.text "air_ops_note"
    t.text "swppp_note"
    t.string "notable_weather_events"
    t.datetime "authorized_date"
    t.integer "contract_day"
    t.text "ai_work_summary"
    t.text "ai_generated_commentary"
    t.string "ai_status", default: "idle"
    t.datetime "ai_generated_at"
    t.text "ai_error"
    t.tsvector "searchable_tsvector"
    t.bigint "authorized_by_id"
    t.string "ai_stage"
    t.index ["ai_status"], name: "index_reports_on_ai_status"
    t.index ["authorized_by_id"], name: "index_reports_on_authorized_by_id"
    t.index ["phase_id"], name: "index_reports_on_phase_id"
    t.index ["project_id", "status"], name: "index_reports_on_project_id_and_status"
    t.index ["project_id"], name: "index_reports_on_project_id"
    t.index ["result"], name: "index_reports_on_result"
    t.index ["searchable_tsvector"], name: "index_reports_on_searchable_tsvector", using: :gin
    t.index ["start_date"], name: "index_reports_on_start_date"
    t.index ["status"], name: "index_reports_on_status"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "spec_items", force: :cascade do |t|
    t.string "code"
    t.string "description"
    t.jsonb "checklist_questions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "division"
    t.index ["code"], name: "index_spec_items_on_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "provider"
    t.string "uid"
    t.string "oid"
    t.string "preferred_username"
    t.string "first_name"
    t.string "last_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["oid"], name: "index_users_on_oid", unique: true, where: "(oid IS NOT NULL)"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "weekly_reports", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.integer "report_number"
    t.integer "status", default: 0, null: false
    t.text "weather_summary"
    t.jsonb "weather_data_json", default: {}
    t.jsonb "completion_data_json", default: {}
    t.text "work_summary"
    t.text "lab_testing_summary"
    t.text "materials_summary"
    t.text "problem_areas"
    t.string "ai_status", default: "idle"
    t.text "ai_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "end_date"], name: "index_weekly_reports_on_project_id_and_end_date", unique: true
    t.index ["project_id", "report_number"], name: "index_weekly_reports_on_project_id_and_report_number", unique: true
    t.index ["project_id"], name: "index_weekly_reports_on_project_id"
    t.index ["user_id"], name: "index_weekly_reports_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activity_logs", "reports"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "approved_equipments", "projects"
  add_foreign_key "bid_items", "projects"
  add_foreign_key "bid_items", "spec_items"
  add_foreign_key "checklist_entries", "reports"
  add_foreign_key "checklist_entries", "spec_items"
  add_foreign_key "crew_entries", "reports"
  add_foreign_key "equipment_entries", "reports"
  add_foreign_key "imported_reports", "projects"
  add_foreign_key "imported_reports", "users"
  add_foreign_key "phases", "projects"
  add_foreign_key "placed_quantities", "bid_items"
  add_foreign_key "placed_quantities", "reports"
  add_foreign_key "qa_entries", "reports"
  add_foreign_key "report_attachments", "reports"
  add_foreign_key "report_exports", "reports"
  add_foreign_key "report_exports", "users"
  add_foreign_key "reports", "phases"
  add_foreign_key "reports", "projects"
  add_foreign_key "reports", "users"
  add_foreign_key "reports", "users", column: "authorized_by_id"
  add_foreign_key "weekly_reports", "projects"
  add_foreign_key "weekly_reports", "users"
end
