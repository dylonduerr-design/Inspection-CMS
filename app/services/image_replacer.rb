require 'zip'
require 'nokogiri'
require 'tempfile'
require 'fileutils'
require 'pathname'

class ImageReplacer
  NAMESPACES = {
    'w'  => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'wp' => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
    'a'  => 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'r'  => 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
  }.freeze

  BASE_PARTS = ["word/document.xml"].freeze

  def self.replace(target_path, replacements)
    return if replacements.blank?

    Rails.logger.info("ImageReplacer: Starting replacement with #{replacements.size} images")
    replacements.each { |k, v| Rails.logger.info("  #{k} => #{v} (exists: #{File.exist?(v)})") }

    # Work directly on a copy of the file
    temp_output = Tempfile.new(['docx_final', '.docx'])
    temp_output.close # Close immediately; we just need the path
    
    FileUtils.cp(target_path, temp_output.path)

    begin
      Zip::File.open(temp_output.path) do |zip|
        parts = discover_parts(zip)
        Rails.logger.info("ImageReplacer: Discovered parts: #{parts.join(', ')}")

        parts.each do |part|
          next unless zip.find_entry(part)

          xml = Nokogiri::XML(zip.read(part))

          replacements.each do |alt_id, image_path|
            next unless File.exist?(image_path)

            # Try both descr and title attributes, and name attribute as fallback
            doc_pr = xml.at_xpath("//wp:docPr[@descr=$alt or @title=$alt or @name=$alt]", NAMESPACES, alt: alt_id)
            unless doc_pr
              Rails.logger.debug("ImageReplacer: No docPr found for '#{alt_id}' in #{part}")
              next
            end

            Rails.logger.info("ImageReplacer: Found docPr for '#{alt_id}' in #{part}")

            # Navigate up to the drawing element and find the blip
            blip = doc_pr.at_xpath("ancestor::w:drawing//a:blip", NAMESPACES)
            unless blip
              Rails.logger.warn("ImageReplacer: No blip found for '#{alt_id}'")
              next
            end

            rid = blip['r:embed']
            unless rid
              Rails.logger.warn("ImageReplacer: No relationship ID found for '#{alt_id}'")
              next
            end

            Rails.logger.info("ImageReplacer: Found relationship ID #{rid} for '#{alt_id}'")

            # Find the relationship file
            rels_path = relationships_path_for(part)
            unless zip.find_entry(rels_path)
              Rails.logger.warn("ImageReplacer: Relationships file not found: #{rels_path}")
              next
            end

            # Parse relationships and find the target image
            rels_doc = Nokogiri::XML(zip.read(rels_path))
            rel_node = rels_doc.at_xpath("//*[@Id=$rid]", {}, rid: rid)
            unless rel_node
              Rails.logger.warn("ImageReplacer: Relationship node not found for ID #{rid}")
              next
            end

            target = resolve_target(part, rel_node['Target'])
            unless target && zip.find_entry(target)
              Rails.logger.warn("ImageReplacer: Target image not found: #{target}")
              next
            end

            Rails.logger.info("ImageReplacer: Replacing #{target} with #{image_path}")
            zip.replace(target, image_path)
            Rails.logger.info("ImageReplacer: Successfully replaced #{target}")
          end
        end
      end

      # Move the modified file back to the original location
      FileUtils.mv(temp_output.path, target_path, force: true)
      Rails.logger.info("ImageReplacer: Completed replacement")
    ensure
      # Clean up temp file if it still exists
      temp_output.unlink if File.exist?(temp_output.path)
    end
  end

  def self.discover_parts(zip)
    parts = BASE_PARTS.dup
    parts.concat(zip.glob('word/header*.xml').map(&:name))
    parts.concat(zip.glob('word/footer*.xml').map(&:name))
    parts.uniq
  end

  def self.relationships_path_for(part_path)
    base = File.dirname(part_path)
    filename = File.basename(part_path, '.xml')
    File.join(base, '_rels', "#{filename}.xml.rels")
  end

  def self.resolve_target(part_path, target)
    return nil unless target

    base_dir = File.dirname(part_path)
    path = Pathname(base_dir).join(target).cleanpath.to_s
    path = path.start_with?('word/') ? path : File.join('word', path)
    path.start_with?('word/') ? path : nil
  end
end