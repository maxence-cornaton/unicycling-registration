class ScoreWeightCalculator::Dismount
  attr_reader :group_size

  def initialize(group_size)
    @group_size = group_size
  end

  def total(score)
    calc_total = if group_size < 3
                   10 - mistake_score(score)
                 else
                   10 - (mistake_score(score) / Math.sqrt(group_size))
                 end
    [calc_total, 0].max.round(4)
  end

  #  1.0 * number of major dismounts + 0.5 * number of minor dismount
  def mistake_score(raw_scores)
    (1.0 * raw_scores[0]) + (0.5 * raw_scores[1])
  end
end
