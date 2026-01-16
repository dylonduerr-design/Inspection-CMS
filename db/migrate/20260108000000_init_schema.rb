class InitSchema < ActiveRecord::Migration[7.1]
  def change
    # --- 1. ENABLE EXTENSIONS ---
    enable_extension "plpgsql"

    # --- 2. ACTIVE STORAGE (File Uploads) ---
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

    create_table "active_storage_attachments", force: :cascade do |t|
      t.string "name", null: false
      t.string "record_type", null: false
      t.bigint "record_id", null: false
      t.bigint "blob_id", null: false
      t.datetime "created_at", null: false
      t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
      t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
    end

    create_table "active_storage_variant_records", force: :cascade do |t|
      t.bigint "blob_id", null: false
      t.string "variation_digest", null: false
      t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
    end

    # --- 3. USERS (Devise) ---
    create_table "users", force: :cascade do |t|
      t.string "email", default: "", null: false
      t.string "encrypted_password", default: "", null: false
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.timestamps null: false
      t.index ["email"], name: "index_users_on_email", unique: true
      t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    end

    # --- 4. CORE LOOKUPS (Projects, Phases, Bid Items) ---
    create_table "projects", force: :cascade do |t|
      t.string "name"
      t.timestamps
    end

    create_table "phases", force: :cascade do |t|
      t.string "name"
      t.timestamps
    end

    create_table "bid_items", force: :cascade do |t|
      t.string "code"
      t.string "description"
      t.string "unit"
      t.jsonb "checklist_questions" # This is your JSONB array
      t.timestamps
    end

    # --- 5. REPORTS (The Core Table) ---
    create_table "reports", force: :cascade do |t|
      t.string "dir_number"
      t.date "start_date"
      t.date "end_date"
      
      # Associations
      t.references :project, null: false, foreign_key: true
      t.references :phase, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      # Workflow
      t.integer "status"
      t.integer "result"

      # Shift Info
      t.string "shift_start"
      t.string "shift_end"
      t.string "foreman" 
      t.string "superintendent"
      
      # Weather
      t.integer "temp_1"; t.integer "temp_2"; t.integer "temp_3"
      t.string "wind_1"; t.string "wind_2"; t.string "wind_3"
      t.string "precip_1"; t.string "precip_2"; t.string "precip_3"
      t.string "weather_summary_1"; t.string "weather_summary_2"; t.string "weather_summary_3"

      # Location / Docs
      t.string "contractor"
      t.string "plan_sheet"
      t.string "relevant_docs"
      t.string "station_start"
      t.string "station_end"

      # Checklists & Compliance
      t.integer "deficiency_status"
      t.text "deficiency_desc"
      t.integer "traffic_control"
      t.integer "environmental"
      t.integer "security"
      t.integer "safety_incident"
      t.text "safety_desc"
      t.integer "air_ops_coordination", default: 0
      t.integer "swppp_controls", default: 0

      # Text Areas
      t.text "commentary"
      t.text "additional_activities"
      t.text "additional_info"
      
      # Legacy / Misc counts (often handled by nested tables now, but kept for safety)
      t.integer "laborer_count"
      t.integer "operator_count"
      t.integer "survey_count"
      t.integer "electrician_count"

      t.timestamps
    end

    # --- 6. NESTED ENTRIES (The Big Four) ---
    
    # Inspection Entries (To be renamed PlacedQuantity later)
    create_table "placed_quantities", force: :cascade do |t|
      t.references :report, null: false, foreign_key: true
      t.references :bid_item, null: false, foreign_key: true
      t.decimal "quantity"
      t.text "notes"
      t.jsonb "checklist_answers", default: {}
      t.timestamps
    end

    create_table "equipment_entries", force: :cascade do |t|
      t.references :report, null: false, foreign_key: true
      t.string "contractor"
      t.string "make_model"
      t.integer "quantity", default: 1
      t.decimal "hours"
      t.timestamps
    end

    create_table "crew_entries", force: :cascade do |t|
      t.references :report, null: false, foreign_key: true
      t.string "contractor"
      t.string "foreman"
      t.string "superintendent"
      t.integer "laborer_count"
      t.integer "operator_count"
      t.integer "survey_count"
      t.integer "electrician_count"
      t.text "notes"
      t.timestamps
    end

    create_table "qa_entries", force: :cascade do |t|
      t.references :report, null: false, foreign_key: true
      t.integer "qa_type"
      t.string "location"
      t.integer "result"
      t.string "remarks"
      t.timestamps
    end

    # --- 7. MISC TABLES ---
    create_table "activity_logs", force: :cascade do |t|
      t.references :report, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text "note"
      t.timestamps
    end

    create_table "report_attachments", force: :cascade do |t|
      t.references :report, null: false, foreign_key: true
      t.string "caption"
      t.timestamps
    end

    # --- 8. FOREIGN KEYS (Active Storage) ---
    add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
    add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  end
end