module LabTestResultsHelper
  def spec_partial_key(spec_code)
    case spec_code
    when "P-401" then "p401_hma"
    when "P-403" then "p403_cores"
    when "P-610" then "p610_concrete"
    else "generic"
    end
  end

  # Picks the column-layout partial based on the actual row shape, not just
  # spec_code — P-401 lots may carry both HMA air-voids rows and cores
  # compaction rows. Returns one of: "p401_hma", "p403_cores", "p610_concrete",
  # "generic".
  def result_view_key(result)
    case result.result_kind
    when LabTestResult::RESULT_KIND_HMA_AIR_VOIDS then "p401_hma"
    when LabTestResult::RESULT_KIND_CORE_COMPACTION then "p403_cores"
    when LabTestResult::RESULT_KIND_CONCRETE_STRENGTH then "p610_concrete"
    else "generic"
    end
  end

  def result_view_label(spec_code, view_key)
    kind_label =
      case view_key
      when "p401_hma" then "Mix Properties"
      when "p403_cores" then "Compaction Cores"
      when "p610_concrete" then "Concrete"
      else nil
      end

    kind_label ? "#{spec_code} — #{kind_label}" : spec_code
  end

  def result_kind_filter_options
    [
      ["All types", nil],
      ["Mix Properties", LabTestResult::RESULT_KIND_HMA_AIR_VOIDS],
      ["Compaction Cores", LabTestResult::RESULT_KIND_CORE_COMPACTION],
      ["Concrete", LabTestResult::RESULT_KIND_CONCRETE_STRENGTH]
    ]
  end

  def lab_result_kind_label(kind)
    LabTestResult.result_kind_label(kind)
  end

  def result_badge_class(result)
    case result.to_s
    when "pass" then "success"
    when "fail" then "danger"
    else "secondary"
    end
  end

  def result_label(result)
    case result.to_s
    when "pass" then "PASS"
    when "fail" then "FAIL"
    else "PENDING"
    end
  end
end
