# Bid Items and Completion Data View

## How overall completion is calculated

The donut value for **Overall completion** is a weighted completion across bid items.

Formula:

$$
overall\_percent = \left(\frac{\sum placed}{\sum target}\right) \times 100
$$

The value is rounded to 1 decimal place.

## What is included in the calculation

- **Placed** quantities come from `PlacedQuantity` records joined to reports in **finalize** status only.
- Optional filters (project and date range) are applied to the placed set before summing.
- **Target** values come from each bid item's `bid_quantity`.
- Bid items with target less than or equal to 0 are excluded from totals.

## Important behavior in Data View

- The donut center displays `@chart_percent` and `@chart_label`.
- When no category is selected, `@chart_percent` is set to `@overall_percent` and label is **Overall completion**.
- When a category is selected, the donut switches to that category's completion instead of the global overall completion.

## Notes

- The overall value is **not** an average of category percentages.
- It is a single ratio of total placed divided by total target for all included bid items.

## Source locations

- `app/controllers/reports_controller.rb`
  - `build_data_view` method (overall, category, and filtering logic)
- `app/views/reports/data_view.html.erb`
  - donut display (`@chart_percent`, `@chart_label`)
