class ScoringClass
  attr_reader :scoring_class, :competition

  def initialize(scoring_class, competition)
    @scoring_class = scoring_class
    @competition = competition
  end

  def self.for(scoring_class, competition)
    new(scoring_class, competition).to_hash
  end

  def to_hash # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize
    case scoring_class
    when "Shortest Time with Tiers"
      {
        calculator: ShortestTimeWithTierCalculator.new,
        exporter: EnteredDataExporter::Time.new(competition),
        helper: RaceScoringClass.new(competition),
        tiers_enabled: true
      }
    when "Shortest Time"
      {
        calculator: RaceResultCalculator.new,
        exporter: EnteredDataExporter::Time.new(competition),
        helper: RaceScoringClass.new(competition)
      }
    when "Longest Time"
      {
        calculator: RaceResultCalculator.new,
        exporter: EnteredDataExporter::Time.new(competition),
        helper: RaceScoringClass.new(competition, false)
      }
    when "Timed Multi-Lap"
      {
        calculator: MultiLapResultCalculator.new,
        exporter: EnteredDataExporter::Time.new(competition),
        helper: RaceScoringClass.new(competition),
        num_laps_enabled: true
      }
    when "Points Low to High"
      {
        calculator: ExternalResultResultCalculator.new,
        helper: PointsScoringClass.new(competition)
      }
    when "Points High to Low"
      {
        calculator: ExternalResultResultCalculator.new,
        helper: PointsScoringClass.new(competition, false)
      }
    when "Freestyle"
      # TENANT with freestyle events - artistic_score_elimination_mode_naucc?
      #
      # naucc2013                    - TRUE
      # naucc2014                    - TRUE
      # naucc2015                    - false
      # unicon2014                   - false

      # the unicon_scoring feature was set to FALSE used by naucc2014/naucc2013.
      # all other conventions have this set to TRUE
      unicon_scoring = !EventConfiguration.singleton.artistic_score_elimination_mode_naucc?
      {
        calculator: ArtisticResultCalculator.new(unicon_scoring),
        exporter: EnteredDataExporter::Score.new(competition),
        # For Freestyle, the judges enter higher scores for better riders
        judge_score_calculator: GenericPlacingPointsCalculator.new(lower_is_better: false),
        helper: ArtisticScoringClass.new(competition)
      }
    when "Artistic Freestyle IUF 2015"
      {
        calculator: ArtisticResultCalculator2015.new,
        exporter: EnteredDataExporter::Score.new(competition),
        judge_score_calculator: Freestyle2015JudgePointsCalculator.new,
        helper: ArtisticScoringClass2015.new(competition)
      }
    when "Artistic Freestyle IUF 2017"
      {
        calculator: ArtisticResultCalculator2017.new,
        exporter: EnteredDataExporter::Score.new(competition),
        judge_score_calculator: Freestyle2017JudgePointsCalculator.new,
        helper: ArtisticScoringClass2017.new(competition)
      }
    when "Artistic Freestyle IUF 2019"
      {
        calculator: ArtisticResultCalculator2017.new, # Same rules as 2017 for these calculations
        exporter: EnteredDataExporter::Score.new(competition),
        judge_score_calculator: Freestyle2019JudgePointsCalculator.new,
        helper: ArtisticScoringClass2019.new(competition)
      }
    when "Flatland"
      scoring_helper = FlatlandScoringClass.new(competition)
      {
        calculator: FlatlandResultCalculator.new,
        exporter: EnteredDataExporter::Score.new(competition),
        judge_score_calculator: GenericPlacingPointsCalculator.new(lower_is_better: scoring_helper.lower_is_better),
        helper: scoring_helper
      }
    when "Flatland IUF 2017"
      scoring_helper = FlatlandScoringClass2017.new(competition)
      {
        calculator: FlatlandResultCalculator2017.new,
        exporter: EnteredDataExporter::Score.new(competition),
        judge_score_calculator: GenericPlacingPointsCalculator.new(lower_is_better: scoring_helper.lower_is_better),
        helper: scoring_helper
      }
    when "Street"
      scoring_helper = StreetScoringClass.new(competition)
      {
        calculator: StreetResultCalculator.new,
        exporter: EnteredDataExporter::Score.new(competition),
        judge_score_calculator: GenericPlacingPointsCalculator.new(lower_is_better: scoring_helper.lower_is_better),
        helper: scoring_helper
      }
    when "Street Final"
      {
        calculator: StreetResultCalculator.new,
        exporter: EnteredDataExporter::Score.new(competition),
        # We know that Street Finals Are ALWAYS lower is better to assign the points
        # But, we want to leave StreetScoringClass as higher_is_better because
        # that way the higher resulting points win.
        judge_score_calculator: GenericPlacingPointsCalculator.new(
          lower_is_better: true,
          points_per_rank: [10, 7, 5, 3, 2, 1]
        ),
        helper: StreetScoringClass.new(competition, false) # this interacts with the judge_score_calculator
      }
    when "High/Long"
      high_long_type(DistanceAttemptFinalManager)
    when "High/Long Preliminary IUF 2015"
      high_long_type(DistanceAttemptPreliminaryManager)
    when "High/Long Final IUF 2015"
      high_long_type(DistanceAttemptFinal2015Manager)
    when "High/Long Preliminary IUF 2017"
      high_long_type(DistanceAttemptPreliminary2017Manager)
    when "Overall Champion"
      {
        calculator: OverallChampionResultCalculator.new(competition.combined_competition, competition),
        helper: OverallChampionScoringClass.new(competition)
      }
    when "Standard Skill"
      {
        calculator: StandardSkillResultCalculator.new,
        helper: StandardSkillScoringClass.new(competition)
      }
    else
      {
        calculator: nil,
        judge_score_calculator: nil,
        helper: nil
      }
    end
  end

  def high_long_type(distance_attempt_manager)
    {
      calculator: DistanceResultCalculator.new,
      exporter: EnteredDataExporter::MaxDistance.new(competition),
      helper: DistanceScoringClass.new(competition),
      high_long_event?: true,
      distance_attempt_manager: distance_attempt_manager
    }
  end
end
