## Vector RAG for AI Commentary — Agent-Ready Implementation Plan

Build a vector-based Retrieval Augmented Generation system for AI commentary generation using Azure OpenAI embeddings and PostgreSQL with `pgvector`, with two curated corpora: example report documents checked into the repo and condensed FAA/spec Markdown files maintained under a new `ai_context` folder. Store chunk embeddings in-app, use hybrid retrieval (vector similarity plus metadata filters and optional keyword tie-breaks), persist retrieval selections for auditability and cache reuse, and include a lightweight admin UI for managing the context library. Keep the retrieval service intent-aware so daily and weekly work summaries can adopt the same infrastructure later without changing the core data model.

---

## Codebase Context for Implementing Agents

### Technology Stack
- **Framework**: Rails 7.1.3 with Importmap (no Webpack/esbuild), Turbo, Stimulus
- **Database**: PostgreSQL (via `pg` gem), no `pgvector` gem yet
- **Background Jobs**: Sidekiq 7.x with Redis, `config.active_job.queue_adapter = :sidekiq`
- **Auth**: Devise + OmniAuth Microsoft Graph (SSO), roles: `inspector`, `qc`, `admin`
- **Frontend**: Stimulus controllers in `app/javascript/controllers/`, ERB views, no React/Vue
- **AI Provider**: Azure OpenAI via direct HTTP (Net::HTTP), no SDK gem
- **Ruby**: 3.2.2

### Existing AI Pipeline Architecture
The AI generation flow is:
1. User triggers via controller action (e.g., `POST /reports/:id/generate_commentary`)
2. Controller calls `report.enqueue_ai_generation!(intent, user)` which sets `ai_status='queued'` and enqueues `ReportAiGenerateJob`
3. Job calls `ReportAi::PayloadBuilder.build(report)` to create a canonical JSON payload
4. Job calls `ReportAi::Generator.for_env` (factory: returns `FakeGenerator` in test, `AzureGenerator` in production)
5. `AzureGenerator#generate!(payload:, intent:)` renders prompts via `PromptTemplates`, calls Azure OpenAI API
6. Result is persisted to report columns (`ai_work_summary` or `ai_generated_commentary`)
7. Frontend polls `GET /reports/:id/ai_status` until complete

### Key Files (Relative Paths)
| File | Role |
|------|------|
| `app/services/report_ai/generator.rb` | Abstract generator interface, factory method, intent validation |
| `app/services/report_ai/azure_generator.rb` | Azure OpenAI HTTP client, map-reduce chunking for large inputs |
| `app/services/report_ai/prompt_templates.rb` | System/user prompts for all intents, placeholder substitution |
| `app/services/report_ai/payload_builder.rb` | Canonical payload schema (v1) from report data |
| `app/jobs/report_ai_generate_job.rb` | Background job for daily report AI generation |
| `app/jobs/weekly_report_ai_generate_job.rb` | Background job for weekly report AI (5 intents) |
| `app/controllers/reports_controller.rb` | Daily report CRUD + AI endpoints |
| `app/controllers/weekly_reports_controller.rb` | Weekly report CRUD + AI endpoints |
| `app/models/report.rb` | Daily report model with `ai_status`, `ai_generated_commentary` fields |
| `app/models/spec_item.rb` | Universal spec: `code` (unique), `description`, `division`, `checklist_questions` (JSONB) |
| `app/models/bid_item.rb` | Project-specific bid item linked to `spec_item`, has `checklist_questions` (JSONB) |
| `app/models/checklist_entry.rb` | Per-report spec checklist answers (JSONB) |
| `app/models/placed_quantity.rb` | Per-report bid item quantities with `checklist_answers` (JSONB) |
| `config/routes.rb` | All routes including AI generation, export, health check |
| `config/database.yml` | PostgreSQL config, production uses `DATABASE_URL` env var |
| `Gemfile` | Dependencies — no `pgvector` or `neighbor` gem yet |
| `db/schema.rb` | Schema version `2026_03_02_000000`, `plpgsql` extension enabled |

### Environment Variables (Existing)
```
AZURE_OPENAI_ENDPOINT        # Base URL: https://{resource}.openai.azure.com
AZURE_OPENAI_API_KEY          # API key for chat completions
AZURE_OPENAI_DEPLOYMENT_NAME  # Deployment for chat (e.g., gpt-4o)
AZURE_OPENAI_API_VERSION      # Default: 2024-12-01-preview
REDIS_URL                     # Redis for Sidekiq + ActionCable
DATABASE_URL                  # PostgreSQL connection (production)
```

### Database Schema Version
Current: `2026_03_02_000000`. All new migrations must use timestamps after this.

### Conventions
- Models use `ActiveRecord` with integer enums (`status`, `result`, `role`)
- JSONB columns used for structured data (`checklist_questions`, `checklist_answers`, `weather_data_json`)
- Jobs inherit from `ApplicationJob`, use `queue_as :default`
- Services namespaced under `ReportAi::` module in `app/services/report_ai/`
- Admin role check: `current_user.admin?` (role enum)
- Audit logging via `AuditLog.create(report:, user:, note:)`
- Controller responses: JSON for API endpoints, Turbo/HTML for views
- Stimulus controllers in `app/javascript/controllers/` with `data-controller` attributes

---

## Implementation Phases

### Phase 0: Infrastructure Setup
**Goal**: Enable `pgvector` in PostgreSQL and configure embedding environment variables.

#### Task 0.1: Add `neighbor` gem
**File**: `Gemfile`
**Action**: Add the `neighbor` gem (Ruby interface for pgvector) after the `pg` gem line.
```ruby
# Vector similarity search via pgvector
gem "neighbor", "~> 0.4"
```
**Then run**: `bundle install`

#### Task 0.2: Enable pgvector extension migration
**File**: `db/migrate/YYYYMMDD000001_enable_pgvector.rb` (use timestamp after `2026_03_02_000000`)
**Action**: Create migration:
```ruby
class EnablePgvector < ActiveRecord::Migration[7.1]
  def up
    enable_extension 'vector'
  end

  def down
    disable_extension 'vector'
  end
end
```
**Validation**: Run `bin/rails db:migrate` and confirm `vector` appears in `schema.rb` under `enable_extension`.

#### Task 0.3: Add embedding environment variables
**File**: `docs/AZURE_SETUP_REQUIREMENTS.md`
**Action**: Add a new section documenting these env vars:
```
AZURE_OPENAI_EMBEDDING_ENDPOINT      # Can be same as AZURE_OPENAI_ENDPOINT or separate resource
AZURE_OPENAI_EMBEDDING_API_KEY       # Can be same as AZURE_OPENAI_API_KEY or separate
AZURE_OPENAI_EMBEDDING_DEPLOYMENT    # e.g., "text-embedding-3-small"
AZURE_OPENAI_EMBEDDING_API_VERSION   # Default: "2024-06-01"
AZURE_OPENAI_EMBEDDING_DIMENSIONS    # Default: 1536 (for text-embedding-3-small)
```

#### Task 0.4: Create `ai_context/` directory structure
**Action**: Create the following directories and seed files:
```
ai_context/
  README.md                    # Explains conventions for adding content
  faa_specs/
    .gitkeep
  example_reports/
    .gitkeep
```

**`ai_context/README.md`** content:
````markdown
# AI Context Library — Source Files

This folder contains curated reference material for the RAG (Retrieval Augmented
Generation) system. Files here are parsed, chunked, and embedded into the
database to provide context during AI commentary generation.

## Folder Structure

- `faa_specs/` — FAA specification guidance, condensed into Markdown. Each file
  covers a spec division or topic area.
- `example_reports/` — Example inspector commentary and report narratives that
  demonstrate the desired writing style and level of detail.

## File Conventions

### YAML Frontmatter (required)
Every Markdown file must begin with YAML frontmatter:

```yaml
---
corpus_type: faa_spec          # or: example_report
title: "P-401 Plant Mix Bituminous Pavements"
spec_codes:                     # optional, for faa_spec files
  - "P-401"
  - "P-403"
divisions:                      # optional, for faa_spec files
  - "400"
tags:                           # optional free-form tags
  - "asphalt"
  - "paving"
  - "compaction"
---
```

### Heading Structure
Use `##` (H2) headings to define chunk boundaries. Each H2 section becomes one
chunk in the vector database. Use `###` (H3) for sub-sections within a chunk.

### Chunk Size Target
Aim for 200-800 words per H2 section. Sections shorter than 50 words will be
merged with the next section. Sections longer than 1200 words will be split at
paragraph boundaries.

### Spec Code References
In FAA spec files, reference spec codes using the format `[P-401]` or
`[P-401-3.2]` so the system can extract them for metadata filtering.
````

---

### Phase 1: Data Model
**Goal**: Create the database tables for corpus sources, chunks, embeddings, and retrieval provenance.

#### Task 1.1: Create `rag_sources` table migration
**File**: `db/migrate/YYYYMMDD000002_create_rag_sources.rb`
```ruby
class CreateRagSources < ActiveRecord::Migration[7.1]
  def change
    create_table :rag_sources do |t|
      # Identity
      t.string  :corpus_type, null: false  # "faa_spec" or "example_report"
      t.string  :title, null: false
      t.string  :source_path, null: false   # relative path from repo root, e.g. "ai_context/faa_specs/p401.md"
      t.string  :source_checksum, null: false  # SHA-256 of file contents

      # Metadata (extracted from frontmatter)
      t.jsonb   :spec_codes, default: []    # ["P-401", "P-403"]
      t.jsonb   :divisions, default: []     # ["400"]
      t.jsonb   :tags, default: []          # ["asphalt", "paving"]

      # State
      t.boolean :active, default: true, null: false
      t.integer :chunks_count, default: 0, null: false  # counter cache

      t.timestamps
    end

    add_index :rag_sources, :corpus_type
    add_index :rag_sources, :source_path, unique: true
    add_index :rag_sources, :active
    add_index :rag_sources, :spec_codes, using: :gin
    add_index :rag_sources, :divisions, using: :gin
    add_index :rag_sources, :tags, using: :gin
  end
end
```

#### Task 1.2: Create `rag_chunks` table migration
**File**: `db/migrate/YYYYMMDD000003_create_rag_chunks.rb`
```ruby
class CreateRagChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :rag_chunks do |t|
      t.references :rag_source, null: false, foreign_key: true

      # Content
      t.text    :content, null: false        # the chunk text
      t.string  :content_checksum, null: false  # SHA-256 of content

      # Position & structure
      t.integer :ordinal, null: false         # 0-based position within source
      t.string  :heading                      # H2 heading text for this chunk
      t.jsonb   :heading_hierarchy, default: []  # ["Division 400", "P-401", "3.2 Compaction"]

      # Metadata (inherited from source + extracted from chunk)
      t.string  :corpus_type, null: false
      t.jsonb   :spec_codes, default: []
      t.jsonb   :divisions, default: []
      t.jsonb   :tags, default: []

      # Embedding
      t.vector  :embedding, limit: 1536      # pgvector column, dimensions configurable
      t.string  :embedding_model              # e.g. "text-embedding-3-small"
      t.string  :embedding_model_version      # e.g. "2024-01-01"
      t.string  :embedding_status, default: "pending", null: false  # pending, completed, failed, stale

      # State
      t.boolean :active, default: true, null: false
      t.integer :token_count                  # approximate token count

      t.timestamps
    end

    add_index :rag_chunks, [:rag_source_id, :ordinal], unique: true
    add_index :rag_chunks, :corpus_type
    add_index :rag_chunks, :embedding_status
    add_index :rag_chunks, :active
    add_index :rag_chunks, :spec_codes, using: :gin
    add_index :rag_chunks, :divisions, using: :gin
    add_index :rag_chunks, :content_checksum
  end
end
```

**Note**: After migration, add an IVFFlat or HNSW index on the `embedding` column. This is done as a separate migration after initial data load so the index can be built on populated data.

#### Task 1.3: Create vector similarity index migration (run after initial data load)
**File**: `db/migrate/YYYYMMDD000004_add_vector_index_to_rag_chunks.rb`
```ruby
class AddVectorIndexToRagChunks < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      CREATE INDEX index_rag_chunks_on_embedding
      ON rag_chunks
      USING hnsw (embedding vector_cosine_ops)
      WITH (m = 16, ef_construction = 64);
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_rag_chunks_on_embedding;"
  end
end
```

#### Task 1.4: Create `rag_retrievals` table migration (provenance/audit)
**File**: `db/migrate/YYYYMMDD000005_create_rag_retrievals.rb`
```ruby
class CreateRagRetrievals < ActiveRecord::Migration[7.1]
  def change
    create_table :rag_retrievals do |t|
      # What triggered this retrieval
      t.string  :intent, null: false          # "commentary", "work_summary", etc.
      t.string  :context_fingerprint, null: false  # SHA-256 of driving fields
      t.string  :retrieval_status, null: false  # "success", "fallback", "error"

      # Report association (polymorphic-ready for weekly_reports later)
      t.bigint  :report_id
      t.string  :report_type, default: "Report"  # "Report" or "WeeklyReport"

      # Embedding model used for query
      t.string  :query_embedding_model
      t.string  :query_embedding_model_version

      # Results
      t.jsonb   :selected_chunks, default: []  # [{chunk_id, score, corpus_type, spec_codes}]
      t.integer :chunks_considered              # total candidates before filtering
      t.integer :chunks_selected                # final count returned
      t.float   :retrieval_latency_ms

      # Error tracking
      t.text    :fallback_reason

      t.timestamps
    end

    add_index :rag_retrievals, :context_fingerprint
    add_index :rag_retrievals, :intent
    add_index :rag_retrievals, [:report_type, :report_id]
    add_index :rag_retrievals, :retrieval_status
  end
end
```

#### Task 1.5: Create `RagSource` model
**File**: `app/models/rag_source.rb`
```ruby
# frozen_string_literal: true

class RagSource < ApplicationRecord
  has_many :rag_chunks, dependent: :destroy

  validates :corpus_type, presence: true, inclusion: { in: %w[faa_spec example_report] }
  validates :title, presence: true
  validates :source_path, presence: true, uniqueness: true
  validates :source_checksum, presence: true

  scope :active, -> { where(active: true) }
  scope :faa_specs, -> { where(corpus_type: "faa_spec") }
  scope :example_reports, -> { where(corpus_type: "example_report") }
  scope :stale, -> { joins(:rag_chunks).where(rag_chunks: { embedding_status: "stale" }).distinct }

  def stale?
    rag_chunks.where(embedding_status: "stale").exists?
  end

  def fully_embedded?
    rag_chunks.where.not(embedding_status: "completed").none?
  end
end
```

#### Task 1.6: Create `RagChunk` model
**File**: `app/models/rag_chunk.rb`
```ruby
# frozen_string_literal: true

class RagChunk < ApplicationRecord
  belongs_to :rag_source, counter_cache: :chunks_count
  has_neighbors :embedding

  validates :content, presence: true
  validates :content_checksum, presence: true
  validates :ordinal, presence: true, uniqueness: { scope: :rag_source_id }
  validates :corpus_type, presence: true
  validates :embedding_status, inclusion: { in: %w[pending completed failed stale] }

  scope :active, -> { where(active: true) }
  scope :embedded, -> { where(embedding_status: "completed") }
  scope :pending_embedding, -> { where(embedding_status: %w[pending stale]) }
  scope :faa_specs, -> { where(corpus_type: "faa_spec") }
  scope :example_reports, -> { where(corpus_type: "example_report") }

  # Filter chunks by spec codes (JSONB array overlap)
  scope :for_spec_codes, ->(codes) {
    where("spec_codes ?| array[:codes]", codes: Array(codes))
  }

  # Filter chunks by divisions (JSONB array overlap)
  scope :for_divisions, ->(divisions) {
    where("divisions ?| array[:divisions]", divisions: Array(divisions))
  }
end
```

#### Task 1.7: Create `RagRetrieval` model
**File**: `app/models/rag_retrieval.rb`
```ruby
# frozen_string_literal: true

class RagRetrieval < ApplicationRecord
  belongs_to :report, polymorphic: true, optional: true

  validates :intent, presence: true
  validates :context_fingerprint, presence: true
  validates :retrieval_status, presence: true, inclusion: { in: %w[success fallback error] }

  scope :for_report, ->(report) {
    where(report_type: report.class.name, report_id: report.id)
  }

  scope :cached_for, ->(fingerprint, embedding_model) {
    where(context_fingerprint: fingerprint, query_embedding_model: embedding_model, retrieval_status: "success")
    .order(created_at: :desc)
    .limit(1)
  }
end
```

---

### Phase 2: Ingestion and Embedding Pipeline
**Goal**: Parse Markdown files from `ai_context/`, chunk them, generate embeddings via Azure OpenAI, and persist everything.

#### Task 2.1: Create the Markdown chunk parser
**File**: `app/services/rag/chunk_parser.rb`
```ruby
# frozen_string_literal: true

require "yaml"
require "digest"

module Rag
  # Parses a Markdown file with YAML frontmatter into chunks.
  # Each H2 (##) section becomes one chunk. Chunks shorter than
  # MIN_CHUNK_WORDS are merged forward. Chunks longer than
  # MAX_CHUNK_WORDS are split at paragraph boundaries.
  class ChunkParser
    MIN_CHUNK_WORDS = 50
    MAX_CHUNK_WORDS = 1200

    Result = Struct.new(:frontmatter, :chunks, keyword_init: true)
    Chunk = Struct.new(:ordinal, :heading, :heading_hierarchy, :content, :spec_codes, keyword_init: true)

    # @param file_path [String] absolute path to the Markdown file
    # @return [Result] parsed frontmatter and chunks array
    def self.parse(file_path)
      new(file_path).parse
    end

    def initialize(file_path)
      @file_path = file_path
      @raw = File.read(file_path, encoding: "utf-8")
    end

    def parse
      frontmatter, body = split_frontmatter(@raw)
      raw_sections = split_on_h2(body)
      merged = merge_small_sections(raw_sections)
      final_chunks = split_large_sections(merged)

      chunks = final_chunks.each_with_index.map do |section, idx|
        spec_codes = extract_spec_codes(section[:content])
        Chunk.new(
          ordinal: idx,
          heading: section[:heading],
          heading_hierarchy: section[:hierarchy],
          content: section[:content].strip,
          spec_codes: spec_codes
        )
      end

      Result.new(frontmatter: frontmatter, chunks: chunks)
    end

    private

    def split_frontmatter(text)
      if text.start_with?("---")
        parts = text.split(/^---\s*$/, 3)
        if parts.length >= 3
          fm = YAML.safe_load(parts[1], permitted_classes: [Date, Time]) || {}
          return [fm.deep_symbolize_keys, parts[2..].join("---")]
        end
      end
      [{}, text]
    end

    def split_on_h2(body)
      sections = []
      current_heading = nil
      current_lines = []
      hierarchy = []

      body.each_line do |line|
        if line.match?(/^## /)
          # Save previous section
          if current_lines.any?
            sections << { heading: current_heading, content: current_lines.join, hierarchy: hierarchy.dup }
          end
          current_heading = line.sub(/^## /, "").strip
          hierarchy = [current_heading]
          current_lines = [line]
        elsif line.match?(/^### /)
          # Track sub-heading in hierarchy but don't split
          sub = line.sub(/^### /, "").strip
          hierarchy = [current_heading, sub].compact
          current_lines << line
        else
          current_lines << line
        end
      end

      # Last section
      if current_lines.any?
        sections << { heading: current_heading, content: current_lines.join, hierarchy: hierarchy.dup }
      end

      sections
    end

    def merge_small_sections(sections)
      return sections if sections.empty?

      merged = []
      sections.each do |section|
        if merged.any? && word_count(merged.last[:content]) < MIN_CHUNK_WORDS
          merged.last[:content] += "\n" + section[:content]
          merged.last[:heading] ||= section[:heading]
          merged.last[:hierarchy] = section[:hierarchy] if section[:hierarchy].any?
        else
          merged << section.dup
        end
      end
      merged
    end

    def split_large_sections(sections)
      result = []
      sections.each do |section|
        if word_count(section[:content]) > MAX_CHUNK_WORDS
          paragraphs = section[:content].split(/\n{2,}/)
          current = { heading: section[:heading], content: "", hierarchy: section[:hierarchy] }
          paragraphs.each do |para|
            if word_count(current[:content]) + word_count(para) > MAX_CHUNK_WORDS && current[:content].present?
              result << current
              current = { heading: section[:heading], content: para, hierarchy: section[:hierarchy] }
            else
              current[:content] += "\n\n" + para
            end
          end
          result << current if current[:content].present?
        else
          result << section
        end
      end
      result
    end

    def extract_spec_codes(text)
      text.scan(/\[([A-Z]-\d{3}(?:-[\d.]+)?)\]/).flatten.uniq
    end

    def word_count(text)
      text.to_s.split(/\s+/).size
    end
  end
end
```

#### Task 2.2: Create the Azure OpenAI embedding client
**File**: `app/services/rag/embedding_client.rb`
```ruby
# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Rag
  # Calls Azure OpenAI embeddings API.
  # Supports batch embedding (up to 16 texts per call per Azure limits).
  class EmbeddingClient
    BATCH_SIZE = 16
    DEFAULT_TIMEOUT = 60

    class EmbeddingError < StandardError; end

    def initialize
      @endpoint = normalize_endpoint(ENV.fetch("AZURE_OPENAI_EMBEDDING_ENDPOINT", ENV["AZURE_OPENAI_ENDPOINT"]))
      @api_key = ENV.fetch("AZURE_OPENAI_EMBEDDING_API_KEY", ENV["AZURE_OPENAI_API_KEY"])
      @deployment = ENV.fetch("AZURE_OPENAI_EMBEDDING_DEPLOYMENT")
      @api_version = ENV.fetch("AZURE_OPENAI_EMBEDDING_API_VERSION", "2024-06-01")
      @dimensions = ENV.fetch("AZURE_OPENAI_EMBEDDING_DIMENSIONS", "1536").to_i
    end

    # @return [String] model identifier for tracking
    def model_identifier
      @deployment
    end

    # @return [Integer] configured embedding dimensions
    def dimensions
      @dimensions
    end

    def self.configured?
      ENV["AZURE_OPENAI_EMBEDDING_DEPLOYMENT"].present? &&
        (ENV["AZURE_OPENAI_EMBEDDING_ENDPOINT"].present? || ENV["AZURE_OPENAI_ENDPOINT"].present?) &&
        (ENV["AZURE_OPENAI_EMBEDDING_API_KEY"].present? || ENV["AZURE_OPENAI_API_KEY"].present?)
    end

    # Embed a single text string
    # @param text [String]
    # @return [Array<Float>] embedding vector
    def embed(text)
      embed_batch([text]).first
    end

    # Embed multiple texts in batches
    # @param texts [Array<String>]
    # @return [Array<Array<Float>>] array of embedding vectors
    def embed_batch(texts)
      results = []
      texts.each_slice(BATCH_SIZE) do |batch|
        response = call_api(batch)
        embeddings = response["data"].sort_by { |d| d["index"] }.map { |d| d["embedding"] }
        results.concat(embeddings)
      end
      results
    end

    private

    def call_api(input_texts)
      uri = build_uri
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["api-key"] = @api_key
      request.body = { input: input_texts, dimensions: @dimensions }.to_json

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = DEFAULT_TIMEOUT
      http.open_timeout = DEFAULT_TIMEOUT

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        error_body = JSON.parse(response.body) rescue { "error" => response.body }
        error_msg = error_body.dig("error", "message") || response.body
        raise EmbeddingError, "Azure Embedding API error (#{response.code}): #{error_msg}"
      end

      JSON.parse(response.body)
    end

    def build_uri
      base = @endpoint.chomp("/")
      URI.parse("#{base}/openai/deployments/#{@deployment}/embeddings?api-version=#{@api_version}")
    end

    def normalize_endpoint(raw)
      raw = raw.to_s.strip
      uri = URI.parse(raw)
      port = uri.port
      default_port = (uri.scheme == "https" ? 443 : 80)
      if port && port != default_port
        "#{uri.scheme}://#{uri.host}:#{port}"
      else
        "#{uri.scheme}://#{uri.host}"
      end
    end
  end
end
```

#### Task 2.3: Create the ingestion service
**File**: `app/services/rag/ingest_service.rb`
```ruby
# frozen_string_literal: true

require "digest"

module Rag
  # Ingests Markdown files from ai_context/ into rag_sources and rag_chunks.
  # Idempotent: unchanged files are skipped, changed files re-chunk, only
  # stale chunks are re-embedded.
  class IngestService
    CONTEXT_ROOT = Rails.root.join("ai_context")

    # @return [Hash] summary of what happened
    def self.run!
      new.run!
    end

    def run!
      stats = { sources_created: 0, sources_updated: 0, sources_unchanged: 0, chunks_created: 0, chunks_removed: 0 }

      markdown_files.each do |file_path|
        relative = file_path.relative_path_from(Rails.root).to_s
        file_checksum = Digest::SHA256.hexdigest(File.read(file_path))

        existing = RagSource.find_by(source_path: relative)

        if existing && existing.source_checksum == file_checksum
          stats[:sources_unchanged] += 1
          next
        end

        parsed = ChunkParser.parse(file_path.to_s)
        fm = parsed.frontmatter

        source_attrs = {
          corpus_type: fm[:corpus_type] || infer_corpus_type(relative),
          title: fm[:title] || File.basename(file_path, ".md").titleize,
          source_checksum: file_checksum,
          spec_codes: fm[:spec_codes] || [],
          divisions: fm[:divisions] || [],
          tags: fm[:tags] || []
        }

        if existing
          existing.update!(source_attrs)
          chunk_stats = sync_chunks(existing, parsed.chunks, fm)
          stats[:sources_updated] += 1
          stats[:chunks_created] += chunk_stats[:created]
          stats[:chunks_removed] += chunk_stats[:removed]
        else
          source = RagSource.create!(source_attrs.merge(source_path: relative))
          create_chunks(source, parsed.chunks, fm)
          stats[:sources_created] += 1
          stats[:chunks_created] += parsed.chunks.size
        end
      end

      stats
    end

    private

    def markdown_files
      Dir.glob(CONTEXT_ROOT.join("**", "*.md")).map { |f| Pathname.new(f) }.sort
    end

    def infer_corpus_type(relative_path)
      if relative_path.include?("faa_specs")
        "faa_spec"
      elsif relative_path.include?("example_reports")
        "example_report"
      else
        "faa_spec"
      end
    end

    def create_chunks(source, chunks, frontmatter)
      chunks.each do |chunk|
        source.rag_chunks.create!(
          content: chunk.content,
          content_checksum: Digest::SHA256.hexdigest(chunk.content),
          ordinal: chunk.ordinal,
          heading: chunk.heading,
          heading_hierarchy: chunk.heading_hierarchy,
          corpus_type: source.corpus_type,
          spec_codes: (Array(frontmatter[:spec_codes]) + Array(chunk.spec_codes)).uniq,
          divisions: Array(frontmatter[:divisions]),
          tags: Array(frontmatter[:tags]),
          embedding_status: "pending",
          token_count: estimate_tokens(chunk.content)
        )
      end
    end

    def sync_chunks(source, new_chunks, frontmatter)
      stats = { created: 0, removed: 0 }
      existing_chunks = source.rag_chunks.order(:ordinal).to_a
      new_checksums = new_chunks.map { |c| Digest::SHA256.hexdigest(c.content) }

      # Remove chunks that no longer exist
      existing_chunks.each do |ec|
        unless new_checksums.include?(ec.content_checksum)
          ec.destroy!
          stats[:removed] += 1
        end
      end

      # Upsert new/changed chunks
      new_chunks.each do |chunk|
        checksum = Digest::SHA256.hexdigest(chunk.content)
        existing = source.rag_chunks.find_by(content_checksum: checksum)

        if existing
          existing.update!(
            ordinal: chunk.ordinal,
            heading: chunk.heading,
            heading_hierarchy: chunk.heading_hierarchy,
            spec_codes: (Array(frontmatter[:spec_codes]) + Array(chunk.spec_codes)).uniq,
            divisions: Array(frontmatter[:divisions]),
            tags: Array(frontmatter[:tags])
          )
        else
          source.rag_chunks.create!(
            content: chunk.content,
            content_checksum: checksum,
            ordinal: chunk.ordinal,
            heading: chunk.heading,
            heading_hierarchy: chunk.heading_hierarchy,
            corpus_type: source.corpus_type,
            spec_codes: (Array(frontmatter[:spec_codes]) + Array(chunk.spec_codes)).uniq,
            divisions: Array(frontmatter[:divisions]),
            tags: Array(frontmatter[:tags]),
            embedding_status: "pending",
            token_count: estimate_tokens(chunk.content)
          )
          stats[:created] += 1
        end
      end

      stats
    end

    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end
  end
end
```

#### Task 2.4: Create the embedding job
**File**: `app/jobs/rag_embed_job.rb`
```ruby
# frozen_string_literal: true

class RagEmbedJob < ApplicationJob
  queue_as :default

  # Embed all pending/stale chunks in batches.
  # @param source_id [Integer, nil] optional — scope to one source
  def perform(source_id = nil)
    unless Rag::EmbeddingClient.configured?
      Rails.logger.warn("[RagEmbedJob] Embedding client not configured, skipping")
      return
    end

    client = Rag::EmbeddingClient.new
    scope = RagChunk.pending_embedding.active
    scope = scope.where(rag_source_id: source_id) if source_id

    chunks = scope.order(:id).limit(500).to_a
    return if chunks.empty?

    Rails.logger.info("[RagEmbedJob] Embedding #{chunks.size} chunks (source_id=#{source_id || 'all'})")

    chunks.each_slice(Rag::EmbeddingClient::BATCH_SIZE) do |batch|
      texts = batch.map(&:content)

      begin
        vectors = client.embed_batch(texts)

        batch.each_with_index do |chunk, idx|
          chunk.update!(
            embedding: vectors[idx],
            embedding_model: client.model_identifier,
            embedding_model_version: Time.current.strftime("%Y-%m-%d"),
            embedding_status: "completed"
          )
        end
      rescue Rag::EmbeddingClient::EmbeddingError => e
        Rails.logger.error("[RagEmbedJob] Batch embedding failed: #{e.message}")
        batch.each { |c| c.update!(embedding_status: "failed") }
      end
    end

    # If there are more pending chunks, re-enqueue
    remaining = scope.count
    if remaining > 0
      Rails.logger.info("[RagEmbedJob] #{remaining} chunks still pending, re-enqueueing")
      self.class.perform_later(source_id)
    end
  end
end
```

#### Task 2.5: Create rake tasks for ingestion and embedding
**File**: `lib/tasks/rag.rake`
```ruby
# frozen_string_literal: true

namespace :rag do
  desc "Ingest Markdown files from ai_context/ into rag_sources and rag_chunks"
  task ingest: :environment do
    puts "Ingesting from ai_context/..."
    stats = Rag::IngestService.run!
    puts "Done! #{stats.inspect}"
  end

  desc "Embed all pending/stale chunks via Azure OpenAI"
  task embed: :environment do
    unless Rag::EmbeddingClient.configured?
      puts "ERROR: Embedding env vars not configured. Set AZURE_OPENAI_EMBEDDING_DEPLOYMENT."
      exit 1
    end

    pending = RagChunk.pending_embedding.active.count
    puts "Embedding #{pending} pending chunks..."
    RagEmbedJob.perform_now
    remaining = RagChunk.pending_embedding.active.count
    puts "Done! #{remaining} chunks still pending."
  end

  desc "Ingest + embed in one step"
  task refresh: :environment do
    Rake::Task["rag:ingest"].invoke
    Rake::Task["rag:embed"].invoke
  end

  desc "Show corpus statistics"
  task stats: :environment do
    total_sources = RagSource.count
    active_sources = RagSource.active.count
    total_chunks = RagChunk.count
    embedded = RagChunk.embedded.count
    pending = RagChunk.pending_embedding.count
    failed = RagChunk.where(embedding_status: "failed").count

    puts "=== RAG Corpus Statistics ==="
    puts "Sources: #{active_sources} active / #{total_sources} total"
    puts "Chunks:  #{embedded} embedded, #{pending} pending, #{failed} failed / #{total_chunks} total"
    puts "FAA Spec chunks:      #{RagChunk.faa_specs.embedded.count}"
    puts "Example Report chunks: #{RagChunk.example_reports.embedded.count}"
  end
end
```

---

### Phase 3: Retrieval and Commentary Integration
**Goal**: Build the retrieval service and wire it into the existing commentary generation pipeline.

#### Task 3.1: Create the retrieval service
**File**: `app/services/rag/retrieval_service.rb`
```ruby
# frozen_string_literal: true

require "digest"

module Rag
  # Retrieves relevant chunks for a given report payload and intent.
  # Hybrid approach: vector similarity is primary, with metadata filtering
  # and spec-code boosting.
  class RetrievalService
    # Retrieval limits
    MAX_CHUNKS = 8            # total chunks returned
    MAX_FAA_SPEC = 5          # max FAA/spec chunks
    MAX_EXAMPLE_REPORT = 3    # max example report chunks
    SIMILARITY_THRESHOLD = 0.3  # minimum cosine similarity
    CONTEXT_BUDGET_CHARS = 6000 # max total characters of retrieved context

    class RetrievalError < StandardError; end

    # @param payload [Hash] canonical report payload from PayloadBuilder
    # @param intent [String] "commentary", "work_summary", etc.
    # @param report [Report, nil] for provenance tracking
    # @return [Hash] { chunks: [...], fingerprint:, cached: }
    def self.retrieve(payload:, intent:, report: nil)
      new(payload: payload, intent: intent, report: report).retrieve
    end

    def initialize(payload:, intent:, report: nil)
      @payload = payload
      @intent = intent.to_s
      @report = report
    end

    def retrieve
      fingerprint = compute_fingerprint

      # Check cache: same fingerprint + embedding model = reuse
      if Rag::EmbeddingClient.configured?
        client = Rag::EmbeddingClient.new
        cached = RagRetrieval.cached_for(fingerprint, client.model_identifier).first
        if cached
          Rails.logger.info("[Rag::RetrievalService] Cache hit for fingerprint=#{fingerprint[0..7]}...")
          return {
            chunks: cached.selected_chunks,
            fingerprint: fingerprint,
            cached: true,
            retrieval_id: cached.id
          }
        end
      end

      # Build query text from payload
      query_text = build_query_text
      spec_codes = extract_spec_codes
      divisions = extract_divisions

      # Embed the query
      client = Rag::EmbeddingClient.new
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      query_embedding = client.embed(query_text)

      # Find similar chunks
      candidates = RagChunk.active.embedded
      candidates_count = candidates.count

      # Use neighbor gem's nearest_neighbors
      results = candidates
        .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
        .limit(MAX_CHUNKS * 3) # over-fetch to allow filtering

      # Score, filter, and rank
      scored = results.map do |chunk|
        base_score = 1.0 - chunk.neighbor_distance  # cosine similarity
        boost = 0.0

        # Boost for matching spec codes
        if spec_codes.any? && (Array(chunk.spec_codes) & spec_codes).any?
          boost += 0.15
        end

        # Boost for matching divisions
        if divisions.any? && (Array(chunk.divisions) & divisions).any?
          boost += 0.05
        end

        final_score = base_score + boost
        { chunk: chunk, score: final_score, base_score: base_score }
      end

      # Filter by threshold
      scored.select! { |s| s[:base_score] >= SIMILARITY_THRESHOLD }

      # Sort by final score descending
      scored.sort_by! { |s| -s[:score] }

      # Apply per-corpus caps and context budget
      selected = apply_limits(scored)

      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(1)

      # Format output
      chunk_data = selected.map do |s|
        {
          chunk_id: s[:chunk].id,
          content: s[:chunk].content,
          heading: s[:chunk].heading,
          score: s[:score].round(4),
          corpus_type: s[:chunk].corpus_type,
          spec_codes: s[:chunk].spec_codes,
          source_title: s[:chunk].rag_source&.title
        }
      end

      # Persist provenance
      retrieval = RagRetrieval.create!(
        intent: @intent,
        context_fingerprint: fingerprint,
        retrieval_status: "success",
        report_id: @report&.id,
        report_type: @report&.class&.name || "Report",
        query_embedding_model: client.model_identifier,
        query_embedding_model_version: Time.current.strftime("%Y-%m-%d"),
        selected_chunks: chunk_data.map { |c| c.except(:content) },
        chunks_considered: candidates_count,
        chunks_selected: chunk_data.size,
        retrieval_latency_ms: elapsed_ms
      )

      {
        chunks: chunk_data,
        fingerprint: fingerprint,
        cached: false,
        retrieval_id: retrieval.id
      }
    end

    private

    def compute_fingerprint
      driving_data = {
        intent: @intent,
        commentary: @payload.dig(:narrative, :commentary),
        bid_item_codes: (@payload[:bid_items] || []).map { |b| b[:code] }.compact.sort,
        spec_codes: (@payload[:spec_checklists] || []).map { |s| s[:code] }.compact.sort,
        qa_types: (@payload[:qa_entries] || []).map { |q| q[:qa_type] }.compact.sort.uniq
      }
      Digest::SHA256.hexdigest(driving_data.to_json)
    end

    def build_query_text
      parts = []

      # Primary: inspector commentary
      commentary = @payload.dig(:narrative, :commentary)
      parts << commentary if commentary.present?

      # Spec codes and descriptions
      specs = (@payload[:spec_checklists] || []).map { |s| "#{s[:code]}: #{s[:description]}" }
      parts.concat(specs.first(5))

      # Bid item descriptions
      bids = (@payload[:bid_items] || []).map { |b| "#{b[:code]}: #{b[:description]}" }
      parts.concat(bids.first(5))

      # QA types
      qa_types = (@payload[:qa_entries] || []).map { |q| q[:qa_type] }.compact.uniq
      parts << "QA testing: #{qa_types.join(', ')}" if qa_types.any?

      parts.join("\n")
    end

    def extract_spec_codes
      codes = []
      codes += (@payload[:spec_checklists] || []).map { |s| s[:code] }.compact
      codes += (@payload[:bid_items] || []).map { |b| b[:code] }.compact
      codes += codes.map { |c| c.match(/([A-Z]-\d{3})/i)&.captures }.flatten.compact
      codes.uniq
    end

    def extract_divisions
      (@payload[:spec_checklists] || []).map { |s| s[:division] }.compact.uniq
    end

    def apply_limits(scored)
      selected = []
      faa_count = 0
      example_count = 0
      total_chars = 0

      scored.each do |entry|
        break if selected.size >= MAX_CHUNKS
        break if total_chars >= CONTEXT_BUDGET_CHARS

        chunk = entry[:chunk]
        if chunk.corpus_type == "faa_spec"
          next if faa_count >= MAX_FAA_SPEC
          faa_count += 1
        elsif chunk.corpus_type == "example_report"
          next if example_count >= MAX_EXAMPLE_REPORT
          example_count += 1
        end

        total_chars += chunk.content.length
        break if total_chars > CONTEXT_BUDGET_CHARS && selected.any?

        selected << entry
      end

      selected
    end
  end
end
```

#### Task 3.2: Create the context fingerprint helper
**File**: `app/services/rag/context_fingerprint.rb`
```ruby
# frozen_string_literal: true

require "digest"

module Rag
  # Computes a stable fingerprint from the fields that drive RAG retrieval.
  # Used for cache hits: if the fingerprint hasn't changed and the embedding
  # model is the same, skip re-retrieval.
  class ContextFingerprint
    # @param payload [Hash] canonical payload from PayloadBuilder
    # @param intent [String]
    # @return [String] SHA-256 hex digest
    def self.compute(payload:, intent:)
      data = {
        intent: intent.to_s,
        commentary: payload.dig(:narrative, :commentary).to_s.strip,
        additional_activities: payload.dig(:narrative, :additional_activities).to_s.strip,
        bid_item_codes: (payload[:bid_items] || []).map { |b| b[:code] }.compact.sort,
        spec_codes: (payload[:spec_checklists] || []).map { |s| s[:code] }.compact.sort,
        divisions: (payload[:spec_checklists] || []).map { |s| s[:division] }.compact.sort.uniq,
        qa_types: (payload[:qa_entries] || []).map { |q| q[:qa_type] }.compact.sort.uniq,
        checklist_answer_keys: extract_checklist_keys(payload)
      }
      Digest::SHA256.hexdigest(data.to_json)
    end

    def self.extract_checklist_keys(payload)
      keys = []
      (payload[:bid_items] || []).each do |bi|
        (bi[:checklist_answers] || {}).each_key { |k| keys << "bid:#{bi[:code]}:#{k}" }
      end
      (payload[:spec_checklists] || []).each do |sc|
        (sc[:checklist_answers] || {}).each_key { |k| keys << "spec:#{sc[:code]}:#{k}" }
      end
      keys.sort
    end
  end
end
```

#### Task 3.3: Add RAG context section to commentary prompt template
**File**: `app/services/report_ai/prompt_templates.rb`
**Action**: Add a new constant `RAG_CONTEXT_ADDENDUM` after the existing `COMMENTARY_USER_PROMPT` constant:

```ruby
    # Appended to the commentary user prompt when RAG context is available
    RAG_CONTEXT_ADDENDUM = <<~PROMPT

      Reference Material (retrieved from FAA specifications and example reports):
      ---BEGIN REFERENCE CONTEXT---
      {{rag_context}}
      ---END REFERENCE CONTEXT---

      IMPORTANT INSTRUCTIONS FOR USING REFERENCE MATERIAL:
      - Use the reference material to inform your writing style, technical accuracy, and level of detail
      - Do NOT copy reference text verbatim — adapt it to this specific report's data
      - Do NOT reference information that contradicts the inspector's actual observations
      - Do NOT invent spec codes, test results, or details not present in the report data
      - If reference material mentions equipment or procedures not in this report, do not include them
    PROMPT
```

**Action**: In the `substitute_placeholders` method, after the line that handles `{{bid_item_checklists}}`, add:
```ruby
        # RAG context (injected by retrieval service, not from payload)
        rag_context = payload[:_rag_context]
        if rag_context.present?
          result += RAG_CONTEXT_ADDENDUM.gsub('{{rag_context}}', rag_context)
        end
```

**Action**: Append to the existing `COMMENTARY_SYSTEM_PROMPT` (before the closing `PROMPT`):
```
      If reference material from FAA specifications or example reports is provided,
      use it to improve technical accuracy and writing quality, but always prioritize
      the actual inspector observations and report data over reference examples.
```

#### Task 3.4: Modify `ReportAiGenerateJob` to include RAG retrieval
**File**: `app/jobs/report_ai_generate_job.rb`
**Action**: In the `perform` method, after the line `payload = ReportAi::PayloadBuilder.build(report)`, add the RAG injection call:

```ruby
      # For commentary intent, attempt RAG retrieval
      if intent.to_s == "commentary"
        payload = inject_rag_context(payload, report)
      end
```

**Action**: Add this private method to the class:

```ruby
    def inject_rag_context(payload, report)
      return payload unless Rag::EmbeddingClient.configured?
      return payload unless RagChunk.active.embedded.exists?

      begin
        retrieval = Rag::RetrievalService.retrieve(
          payload: payload,
          intent: "commentary",
          report: report
        )

        if retrieval[:chunks].any?
          context_text = retrieval[:chunks].map do |chunk|
            source_label = chunk[:source_title] || chunk[:corpus_type]
            "[#{source_label}] #{chunk[:heading]}\n#{chunk[:content]}"
          end.join("\n\n---\n\n")

          payload[:_rag_context] = context_text
          Rails.logger.info("[ReportAiGenerateJob] RAG context injected: #{retrieval[:chunks].size} chunks, cached=#{retrieval[:cached]}")
        end
      rescue StandardError => e
        Rails.logger.warn("[ReportAiGenerateJob] RAG retrieval failed, continuing without context: #{e.message}")
        RagRetrieval.create!(
          intent: "commentary",
          context_fingerprint: Rag::ContextFingerprint.compute(payload: payload, intent: "commentary"),
          retrieval_status: "error",
          report_id: report.id,
          report_type: "Report",
          fallback_reason: e.message
        )
      end

      payload
    end
```

---

### Phase 4: Admin UI
**Goal**: Lightweight admin interface for managing the RAG corpus.

#### Task 4.1: Create the `RagSourcesController`
**File**: `app/controllers/rag_sources_controller.rb`
```ruby
# frozen_string_literal: true

class RagSourcesController < ApplicationController
  before_action :require_admin
  before_action :set_source, only: [:show, :toggle_active, :reembed]

  def index
    @sources = RagSource.order(:corpus_type, :title)
    @stats = {
      total_sources: RagSource.count,
      active_sources: RagSource.active.count,
      total_chunks: RagChunk.count,
      embedded_chunks: RagChunk.embedded.count,
      pending_chunks: RagChunk.pending_embedding.count,
      failed_chunks: RagChunk.where(embedding_status: "failed").count,
      recent_retrievals: RagRetrieval.where("created_at > ?", 7.days.ago).count
    }
  end

  def show
    @chunks = @source.rag_chunks.order(:ordinal)
  end

  def toggle_active
    @source.update!(active: !@source.active)
    @source.rag_chunks.update_all(active: @source.active)
    redirect_to rag_source_path(@source), notice: "Source #{@source.active? ? 'activated' : 'deactivated'}."
  end

  def reindex
    Rag::IngestService.run!
    redirect_to rag_sources_path, notice: "Re-ingestion complete."
  end

  def reembed
    @source.rag_chunks.where(embedding_status: "completed").update_all(embedding_status: "stale")
    RagEmbedJob.perform_later(@source.id)
    redirect_to rag_source_path(@source), notice: "Re-embedding queued for #{@source.title}."
  end

  def refresh_all
    Rag::IngestService.run!
    RagEmbedJob.perform_later
    redirect_to rag_sources_path, notice: "Full refresh queued."
  end

  private

  def set_source
    @source = RagSource.find(params[:id])
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Admin access required."
    end
  end
end
```

#### Task 4.2: Add routes for RAG admin
**File**: `config/routes.rb`
**Action**: Add inside the `Rails.application.routes.draw` block, after the `resources :spec_items` line:

```ruby
  # RAG Context Library (admin only)
  resources :rag_sources, only: [:index, :show] do
    member do
      post :toggle_active
      post :reembed
    end
    collection do
      post :reindex
      post :refresh_all
    end
  end
```

#### Task 4.3: Create the index view
**File**: `app/views/rag_sources/index.html.erb`

Create an admin page showing:
- Stats banner: total sources, active sources, embedded/pending/failed chunk counts, recent retrievals
- Table listing all sources with columns: Title, Corpus Type, Spec Codes, Chunks Count, Embedding Status (badge: all embedded / N pending / N failed), Active toggle, Actions (View, Reembed)
- Action buttons at top: "Reindex All" (POST to reindex), "Refresh All" (POST to refresh_all)
- Follow existing app styling conventions (standard Rails ERB)

#### Task 4.4: Create the show view
**File**: `app/views/rag_sources/show.html.erb`

Create a detail page for a single source showing:
- Source metadata: title, corpus_type, source_path, checksum, spec_codes, divisions, tags, active status
- Toggle active button
- Reembed button
- Chunks table: ordinal, heading, content preview (first 200 chars), token count, embedding status badge

#### Task 4.5: Add navigation link for admins
**Action**: In the main application layout or navigation partial, add a link visible only to admins:
```erb
<% if current_user&.admin? %>
  <%= link_to "AI Context Library", rag_sources_path %>
<% end %>
```

---

### Phase 5: Expansion Path (Design Only — No Code Changes)
**Goal**: Ensure the architecture supports future work summary intents.

#### Design Constraints (enforce during implementation)
1. `Rag::RetrievalService` accepts any `intent` string — do not hard-code to "commentary"
2. `RagRetrieval` uses `intent` column to distinguish retrieval purposes
3. `context_fingerprint` includes `intent` so the same report with different intents gets separate cache entries
4. `MAX_CHUNKS`, `MAX_FAA_SPEC`, `MAX_EXAMPLE_REPORT` should be extractable into per-intent configuration later (constants are fine for now, but keep them in one place)
5. Prompt addendum (`RAG_CONTEXT_ADDENDUM`) is only appended for commentary intent currently, but the mechanism (checking `payload[:_rag_context]`) can be added to other prompt templates later
6. The `report_type` column on `RagRetrieval` is `"Report"` or `"WeeklyReport"` — when wiring weekly summaries, pass the `WeeklyReport` instance

---

## File Manifest — All Files to Create or Modify

### New Files to Create
| File | Phase | Description |
|------|-------|-------------|
| `ai_context/README.md` | 0 | Source file conventions documentation |
| `ai_context/faa_specs/.gitkeep` | 0 | Placeholder for FAA spec Markdown |
| `ai_context/example_reports/.gitkeep` | 0 | Placeholder for example report Markdown |
| `db/migrate/YYYYMMDD000001_enable_pgvector.rb` | 0 | Enable vector extension |
| `db/migrate/YYYYMMDD000002_create_rag_sources.rb` | 1 | Sources table |
| `db/migrate/YYYYMMDD000003_create_rag_chunks.rb` | 1 | Chunks table with vector column |
| `db/migrate/YYYYMMDD000004_add_vector_index_to_rag_chunks.rb` | 1 | HNSW index on embeddings |
| `db/migrate/YYYYMMDD000005_create_rag_retrievals.rb` | 1 | Retrieval provenance table |
| `app/models/rag_source.rb` | 1 | RagSource model |
| `app/models/rag_chunk.rb` | 1 | RagChunk model with `has_neighbors` |
| `app/models/rag_retrieval.rb` | 1 | RagRetrieval model |
| `app/services/rag/chunk_parser.rb` | 2 | Markdown parser to chunks |
| `app/services/rag/embedding_client.rb` | 2 | Azure OpenAI embeddings HTTP client |
| `app/services/rag/ingest_service.rb` | 2 | File to DB ingestion pipeline |
| `app/services/rag/context_fingerprint.rb` | 3 | Fingerprint computation |
| `app/services/rag/retrieval_service.rb` | 3 | Vector retrieval + ranking |
| `app/jobs/rag_embed_job.rb` | 2 | Background embedding job |
| `lib/tasks/rag.rake` | 2 | Rake tasks: ingest, embed, refresh, stats |
| `app/controllers/rag_sources_controller.rb` | 4 | Admin controller |
| `app/views/rag_sources/index.html.erb` | 4 | Admin index view |
| `app/views/rag_sources/show.html.erb` | 4 | Admin detail view |

### Existing Files to Modify
| File | Phase | Change |
|------|-------|--------|
| `Gemfile` | 0 | Add `gem "neighbor", "~> 0.4"` |
| `docs/AZURE_SETUP_REQUIREMENTS.md` | 0 | Add embedding env vars section |
| `app/services/report_ai/prompt_templates.rb` | 3 | Add `RAG_CONTEXT_ADDENDUM` constant, add `{{rag_context}}` handling in `substitute_placeholders`, append reference material note to `COMMENTARY_SYSTEM_PROMPT` |
| `app/jobs/report_ai_generate_job.rb` | 3 | Add `inject_rag_context` private method, call it for commentary intent before generation |
| `config/routes.rb` | 4 | Add `resources :rag_sources` routes |
| App layout/nav partial | 4 | Add admin link to "AI Context Library" |

---

## Verification Checklist

Run these checks after each phase:

### After Phase 0
```bash
bin/rails db:migrate
bin/rails runner "ActiveRecord::Base.connection.execute('SELECT vector_dims(NULL::vector)');"
# Should execute without error
ls ai_context/faa_specs/ ai_context/example_reports/
# Should show .gitkeep files
bundle list | grep neighbor
# Should show neighbor gem
```

### After Phase 1
```bash
bin/rails db:migrate
bin/rails runner "puts RagSource.table_name; puts RagChunk.table_name; puts RagRetrieval.table_name"
# Should print table names without error
bin/rails runner "RagSource.create!(corpus_type: 'faa_spec', title: 'Test', source_path: 'test.md', source_checksum: 'abc123')"
# Should create without error, then clean up
```

### After Phase 2
```bash
# Create a test Markdown file in ai_context/faa_specs/test_spec.md with frontmatter
bin/rails rag:ingest
# Should report sources_created: 1, chunks_created: N
bin/rails rag:ingest
# Should report sources_unchanged: 1 (idempotent)
bin/rails rag:stats
# Should show chunk counts
# If embedding env vars configured:
bin/rails rag:embed
# Should embed pending chunks
```

### After Phase 3
```bash
# With at least one embedded chunk and a report with commentary:
bin/rails runner "
  report = Report.where.not(commentary: [nil, '']).first
  payload = ReportAi::PayloadBuilder.build(report)
  result = Rag::RetrievalService.retrieve(payload: payload, intent: 'commentary', report: report)
  puts \"Chunks retrieved: #{result[:chunks].size}\"
  puts \"Cached: #{result[:cached]}\"
  puts \"Fingerprint: #{result[:fingerprint][0..15]}...\"
"
# Should retrieve chunks without error

# Test graceful fallback (unset embedding env temporarily):
bin/rails runner "
  report = Report.where.not(commentary: [nil, '']).first
  payload = ReportAi::PayloadBuilder.build(report)
  # inject_rag_context returns payload unchanged when embedding not configured
  puts 'Fallback works' unless payload.key?(:_rag_context)
"
```

### After Phase 4
```bash
bin/rails routes | grep rag_source
# Should show index, show, toggle_active, reembed, reindex, refresh_all routes
# Visit /rag_sources as admin user — should see the library UI
# Visit /rag_sources as non-admin — should redirect to root
```

### Full Integration Test
1. Add a real FAA spec Markdown file to `ai_context/faa_specs/`
2. Run `bin/rails rag:refresh`
3. Verify chunks are embedded: `bin/rails rag:stats`
4. Generate commentary for a report that uses a matching spec code
5. Check `RagRetrieval.last` — should have `retrieval_status: "success"` with selected chunks
6. Generate commentary again for the same report — should show `cached: true` in logs
7. Change the report's commentary text and regenerate — should show `cached: false` (new fingerprint)

---

## Decisions
- Retrieval is vector-first from the start, not a keyword-first MVP.
- Phase 1 scope remains daily expanded commentary only. Daily and weekly work summaries are still excluded from initial wiring, though the architecture supports them later.
- Example-report corpus comes from Markdown files checked into the repo under `ai_context/example_reports/`, not from the app's historical report database.
- FAA/spec corpus comes from Markdown maintained under `ai_context/faa_specs/`, not from current `docs/` files.
- MVP includes a lightweight admin UI, but source text remains maintained in repo files; the UI manages metadata, chunk visibility, and reindex/re-embed operations.
- Retrieval uses hybrid scoring: vector cosine similarity is primary, with spec-code and division match boosting.
- The `neighbor` gem (pgvector Ruby binding) is used rather than raw SQL for vector queries.
- Embedding deployment is configured separately from chat deployment via dedicated env vars, with fallback to chat deployment env vars for simpler setups.
- Graceful fallback: if embedding service or retrieval fails, commentary generation proceeds without RAG context and logs the fallback reason.

## Further Considerations
1. **Embedding model separation**: The embedding deployment (`AZURE_OPENAI_EMBEDDING_DEPLOYMENT`) is intentionally separate from the chat deployment (`AZURE_OPENAI_DEPLOYMENT_NAME`) so model swaps and re-embedding runs do not disrupt commentary generation.
2. **Embedding versioning**: Each chunk records `embedding_model` and `embedding_model_version` so future re-embeds can coexist during migrations rather than forcing an all-at-once rebuild.
3. **Fallback path**: If production PostgreSQL cannot support `pgvector`, the same ingestion/chunk model works with an external vector store. The `Rag::RetrievalService` is the only class that issues vector queries — swapping the backing store requires changes only there.
4. **Token estimation**: Chunk `token_count` uses a rough `length/4` estimate. For production accuracy, consider integrating a tokenizer library (e.g., `tiktoken_ruby`) but this is not required for MVP.
5. **HNSW index tuning**: The initial HNSW index uses `m=16, ef_construction=64`. With fewer than 10,000 chunks these defaults are fine. Tune if the corpus grows significantly.
