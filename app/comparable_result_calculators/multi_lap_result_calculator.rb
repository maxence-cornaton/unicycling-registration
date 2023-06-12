class MultiLapResultCalculator
  # describes whether the given competitor has any results associated
  def competitor_has_result?(competitor)
    competitor.finish_time_results.any?
  end

  # returns the result for this competitor
  def competitor_result(competitor)
    if competitor.has_result?
      return if competitor.best_time_in_thousands.zero?

      result = TimeResultPresenter.from_thousands(competitor.best_time_in_thousands, data_entry_format: competitor.competition.data_entry_format).full_time.to_s
      if competitor.competition.hide_max_laps_count? && (competitor.num_laps == competitor.competition.max_laps)
        return result
      end

      "#{result} (#{ActionController::Base.helpers.pluralize(competitor.num_laps.to_i, 'lap')})"
    end
  end

  # returns the result for this competitor
  # In this case, a lower number is a better number.
  # this is done so that the lap-time is properly taken into account
  def competitor_comparable_result(competitor, with_ineligible: nil) # rubocop:disable Lint/UnusedMethodArgument
    if competitor.has_result?
      lap_time(competitor.num_laps) + competitor.best_time_in_thousands
    else
      0
    end
  end

  def competitor_tie_break_comparable_result(_competitor)
    nil
  end

  def eager_load_results_relations(competitors)
    competitors.includes(
      :start_time_results,
      :finish_time_results
    )
  end

  private

  # convert 1 lap int 9900000000, 2 laps into 980000000000....thus sorting by shortest time correctly.
  def lap_time(num_laps)
    raise "Unable to process >= 100 laps" if num_laps >= 100

    ((100 - num_laps) * 100000000)
  end
end
