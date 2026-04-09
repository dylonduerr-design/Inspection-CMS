require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'

class PythonDocxImporter
  def self.parse(docx_path)
    raise ArgumentError, "docx_path required" if docx_path.blank?

    python_script = Rails.root.join('python', 'import_docx.py')
    venv_python = Rails.root.join('.venv', 'bin', 'python')
    venv_python3 = Rails.root.join('.venv', 'bin', 'python3')

    unless File.exist?(python_script)
      raise "Importer script not found: #{python_script}"
    end

    python_cmd = [venv_python, venv_python3].find { |path| File.exist?(path) } || 'python3'

    if python_cmd == 'python3'
      Rails.logger.warn("PythonDocxImporter: .venv interpreter not found, falling back to system python3")
    end

    extract_dir = Dir.mktmpdir(['docx_import_', ''])
    begin
      cmd = [
        python_cmd.to_s,
        python_script.to_s,
        '--input', docx_path.to_s,
        '--extract-dir', extract_dir.to_s
      ]

      stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        Rails.logger.error("PythonDocxImporter: Python script failed")
        Rails.logger.error("STDOUT: #{stdout}")
        Rails.logger.error("STDERR: #{stderr}")
        raise "Import failed: #{stderr.strip.lines.last.to_s.strip}"
      end

      result = JSON.parse(stdout)
      result['extract_dir'] = extract_dir
      result
    rescue
      FileUtils.remove_entry(extract_dir) if extract_dir && Dir.exist?(extract_dir)
      raise
    end
  end
end
