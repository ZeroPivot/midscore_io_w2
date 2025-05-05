class MoonPhaseDetails2
  # === Constants and Definitions ===

  # Average length of a full lunar cycle (in days)
  MOON_CYCLE_DAYS = 29.53

  # The 15 fabled moon rotations with emojis:
  MOON_ROTATIONS = [
    'New Moon',            # 0
    'Waxing Crescent',     # 1
    'First Quarter',       # 2
    'Waxing Gibbous', # 3
    'Full Moon',           # 4
    'Waning Gibbous',      # 5
    'Last Quarter',        # 6
    'Waning Crescent',     # 7
    'Supermoon',           # 8
    'Blue Moon',         # 9
    'Blood Moon',        # 10
    'Harvest Moon',      # 11
    "Hunter's Moon",     # 12
    'Wolf Moon',         # 13
    'Pink Moon'          # 14
  ]

  # Define 15 corresponding species with emojis.
  SPECIES = [
    'Dogg', # New Moon
    'Folf', # Waxing Crescent
    'Aardwolf',                 # First Quarter
    'Spotted Hyena',            # Waxing Gibbous
    'Folf Hybrid',             # Full Moon
    'Striped Hyena',            # Waning Gibbous
    'Dogg Prime',              # Last Quarter
    'WolfFox', # Waning Crescent
    'Brown Hyena',              # Supermoon
    'Dogg Celestial',          # Blue Moon
    'Folf Eclipse',            # Blood Moon
    'Aardwolf Luminous', # Harvest Moon
    'Spotted Hyena Stellar', # Hunter's Moon
    'Folf Nova', # Wolf Moon
    'Brown Hyena Cosmic' # Pink Moon
  ]

  # Define 15 corresponding were-forms with emojis.
  WERE_FORMS = [
    'WereDogg',                     # New Moon
    'WereFolf',                     # Waxing Crescent
    'WereAardwolf',                   # First Quarter
    'WereSpottedHyena',               # Waxing Gibbous
    'WereFolfHybrid',                # Full Moon
    'WereStripedHyena',               # Waning Gibbous
    'WereDoggPrime',                 # Last Quarter
    'WereWolfFox', # Waning Crescent
    'WereBrownHyena',                 # Supermoon
    'WereDoggCelestial',             # Blue Moon
    'WereFolfEclipse',               # Blood Moon
    'WereAardwolfLuminous',          # Harvest Moon
    'WereSpottedHyenaStellar',       # Hunter's Moon
    'WereFolfNova', # Wolf Moon
    'WereBrownHyenaCosmic', # Pink Moon
  ]

  # Each moon phase is assumed to share an equal slice of the lunar cycle.
  PHASE_COUNT  = MOON_ROTATIONS.size # 15 total phases
  PHASE_LENGTH = MOON_CYCLE_DAYS / PHASE_COUNT # Days per phase

  # === Core Function ===

  # Calculate the current moon phase details based on the given date.
  # Returns: current phase, corresponding species, corresponding were-form, and consciousness level as a string.
  # Consciousness is defined as the fraction (as a percent) given by (raw phase index / 14).
  # For example, 0/14 means 0% conscious, 7/14 means 50% conscious, 14/14 means 100%,
  # and values exceeding 14/14 represent an overcharge beyond full awareness.
  def self.current_moon_details(date)
    # Use a reference new moon date (commonly: January 6, 2000)
    reference_date = Date.new(2000, 1, 6)

    # Calculate the number of days elapsed between the provided date and the reference date.
    days_since_reference = (date - reference_date).to_f

    # Determine the current position within the lunar cycle.
    lunar_position = days_since_reference % MOON_CYCLE_DAYS

    # Compute the raw phase index (as a floating-point number).
    phase_index_raw = lunar_position / PHASE_LENGTH
    phase_index = phase_index_raw.floor

    # Calculate the consciousness percentage.
    # We use (PHASE_COUNT - 1) because our index runs from 0 to 14.
    # This yields 0% when the raw index is 0 and 100% when it reaches 14.
    # Values above 14 indicate an overcharge (i.e. above 100%).
    conscious_percentage = (phase_index_raw / (PHASE_COUNT - 1).to_f) * 100

    # Get the corresponding moon phase details.
    current_phase     = MOON_ROTATIONS[phase_index % MOON_ROTATIONS.size]
    current_species   = SPECIES[phase_index % SPECIES.size]
    current_were_form = WERE_FORMS[phase_index % WERE_FORMS.size]

    # Build a string representing the consciousness level as "X/14 (Y%)"
    consciousness_level = "#{phase_index_raw}/#{PHASE_COUNT - 1} (#{conscious_percentage}%)"

    [current_phase, current_species, current_were_form, consciousness_level, conscious_percentage, phase_index_raw]
  end

  # === HTML-Generating Functions ===

  # Returns an HTML snippet with the complete 15-phase rotation schedule.
  def self.render_full_schedule_html
    rows = ''
    MOON_ROTATIONS.each_with_index do |phase_name, index|
      rows << <<~ROW
        <tr>
          <td>#{phase_name}</td>
          <td>#{SPECIES[index]}</td>
          <td>#{WERE_FORMS[index]}</td>
        </tr>
      ROW
    end

    <<~HTML
      <div class="container">
        <h1>Complete Moon Rotation Schedule</h1>
        <table>
          <thead>
            <tr>
              <th>Moon Phase</th>
              <th>Species</th>
              <th>Were-Form</th>
            </tr>
          </thead>
          <tbody>
            #{rows}
          </tbody>
        </table>
      </div>
    HTML
  end

  # Returns an HTML snippet displaying all details for the given date.
  def self.print_details_for_date(date)
    phase, species, were_form, consciousness, consciousness_percentage, phase_index_raw = current_moon_details(date)
    "<p>
        Moon Phase: #{phase}<br />
        Species: #{species}<br />
        Were-Form: #{were_form}<br />
        Consciousness: #{consciousness}<br />
        Miade-Score/Infini-Vaeria Consciousness: #{1 - (consciousness_percentage / 100)}% (#{1 - (phase_index_raw / PHASE_COUNT - 1)}%)<br />
      </p>"
  end

  def self.print_text_details_for_date(date)
    phase, species, were_form, consciousness, consciousness_percentage, phase_index_raw = current_moon_details(date)
    " Moon Phase: #{phase}\n
        Species: #{species}\n
        Were-Form: #{were_form}\n
        Consciousness: #{consciousness}\n
        Miade-Score/Infini-Vaeria Consciousness:\n #{1 - (consciousness_percentage / 100)}%\n (#{1 - (phase_index_raw / PHASE_COUNT - 1).round(2)}%)\n"
  end
end

class CGMFS
  hash_branch 'moon' do |r|
    r.on do
      # family_logged_in?(r) # -- TEMP FAILSAFE (v9.0.0.1)
      r.get do
        "#{MoonPhaseDetails2.print_text_details_for_date(Date.today)}"
      end
    end
  end
end
