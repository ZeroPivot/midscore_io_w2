require 'uri'
require 'fastimage'
require 'fileutils'
require 'tzinfo'
require 'redcarpet'
require 'json'
require 'oj'

#
# rubocop:disable Style/RedundantInterpolation
# rubocop:disable Layout/LineLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/ClassLength
module Math
  def self.radians(angle)
    angle / 180.0 * Math::PI
  end
end

require 'time'

# ========================================================
# Date Formatter - Pacific Standard Time (PST) 🌍⏳
# Prints date in "Month, Day, Year - TimeInPST" format
# ========================================================

def formatted_pst_time
  pst_time = Time.now.getlocal('-07:00')
  pst_time.strftime('%B, %d, %Y - %I:%M:%S %p SLT/PST')
end

# Print the formatted date
puts formatted_pst_time

class SunPhase
  attr_reader :name, :start_hour, :emoji

  def initialize(name, start_hour, emoji)
    @name = name
    @start_hour = start_hour
    @emoji = emoji
  end
end

class SolarDance
  PHASES = [
    SunPhase2.new('Midnight Mystery', 0, '🌑'),
    SunPhase2.new('Early Dawn', 1, '🌒'),
    SunPhase2.new('Morning Whisper', 2, '🌄'),
    SunPhase2.new('Dawn\'s Whisper', 3, '🌅'),
    SunPhase2.new('First Light\'s Murmur', 5, '🔅'),
    SunPhase2.new('Golden Awakening', 6, '☀️'),
    SunPhase2.new('Morning Glow', 8, '🌞'),
    SunPhase2.new('High Noon Radiance', 12, '🔥'),
    SunPhase2.new('Afternoon Brilliance', 15, '🌇'),
    SunPhase2.new('Golden Hour Serenade', 17, '🌆'),
    SunPhase2.new('Twilight Poetry', 18, '🌒'),
    SunPhase2.new('Dusky Secrets', 19, '🌓'),
    SunPhase2.new('Crimson Horizon', 20, '🌔'),
    SunPhase2.new('Moon\'s Ascent', 21, '🌕'),
    SunPhase2.new('Nightfall\'s Caress', 22, '✨'),
    SunPhase2.new('Deep Celestial Silence', 23, '🌌'),
    SunPhase2.new('Cosmic Slumber', 24, '🌠')
  ]

  def self.current_phase
    pst_hour = Time.now.getlocal('-08:00').hour # Pacific Standard Time (PST)
    PHASES.reverse.find { |phase| pst_hour >= phase.start_hour }
  end

  def self.sun_dance_message
    phase = current_phase
    "🌞 The Sun is currently in '#{phase.name}' phase! #{phase.emoji}"
  end
end

# Execute SunDance
# puts SolarDance.sun_dance_message

# BEGIN: 6f7b8d9hjkl3

# === Constants and Definitions ===

# Average length of a full lunar cycle (in days)
MOON_CYCLE_DAYS = 29.53

# The 17 fabled moon rotations with emojis:
MOON_ROTATIONS = [
  'New Moon 🌑',            # 0
  'Waxing Crescent 🌒',     # 1
  'First Quarter 🌓',       # 2
  'Waxing Gibbous 🌔', # 3
  'Full Moon 🌕',           # 4
  'Waning Gibbous 🌖',      # 5
  'Last Quarter 🌗',        # 6
  'Waning Crescent 🌘',     # 7
  'Supermoon 🌝',           # 8
  'Blue Moon 🔵🌙',         # 9
  'Blood Moon 🩸🌙',        # 10
  'Harvest Moon 🍂🌕',      # 11
  "Hunter's Moon 🌙🔭",     # 12
  'Wolf Moon 🐺🌕',         # 13
  'Pink Moon 🌸🌕',
  'Snow Moon 🌨️', # 14
  'Snow Moon Snow 🌨️❄️', # 15
  'Avian Moon 🦅',          # 16
  'Avian Moon Snow 🦅❄️'    # 17
]

# Define 15 corresponding species with emojis.
SPECIES = [
  'Dogg 🐶', # New Moon
  'Folf 🦊🐺', # Waxing Crescent
  'Aardwolf 🐾',                 # First Quarter
  'Spotted Hyena 🐆',            # Waxing Gibbous
  'Folf Hybrid 🦊✨',             # Full Moon
  'Striped Hyena 🦓',            # Waning Gibbous
  'Dogg Prime 🐕⭐',              # Last Quarter
  'WolfFox 🐺🦊', # Waning Crescent
  'Brown Hyena 🦴',              # Supermoon
  'Dogg Celestial 🐕🌟',          # Blue Moon
  'Folf Eclipse 🦊🌒',            # Blood Moon
  'Aardwolf Luminous 🐾✨', # Harvest Moon
  'Spotted Hyena Stellar 🐆⭐', # Hunter's Moon
  'Folf Nova 🦊💥', # Wolf Moon
  'Brown Hyena Cosmic 🦴🌌', # Pink Moon
  'Snow Leopard 🌨️', # New Moon
  'Snow Leopard Snow Snep 🌨️❄️', # Pink Moon
  'Avian 🦅', # New Moon
  'Avian Snow 🦅❄️' # Pink Moon
]

# Define 15 corresponding were-forms with emojis.
WERE_FORMS = [
  'WereDogg 🐶🌑',                     # New Moon
  'WereFolf 🦊🌙',                     # Waxing Crescent
  'WereAardwolf 🐾',                   # First Quarter
  'WereSpottedHyena 🐆',               # Waxing Gibbous
  'WereFolfHybrid 🦊✨',                # Full Moon
  'WereStripedHyena 🦓',               # Waning Gibbous
  'WereDoggPrime 🐕⭐',                 # Last Quarter
  'WereWolfFox 🐺🦊', # Waning Crescent
  'WereBrownHyena 🦴',                 # Supermoon
  'WereDoggCelestial 🐕🌟',             # Blue Moon
  'WereFolfEclipse 🦊🌒',               # Blood Moon
  'WereAardwolfLuminous 🐾✨',          # Harvest Moon
  'WereSpottedHyenaStellar 🐆⭐',       # Hunter's Moon
  'WereFolfNova 🦊💥', # Wolf Moon
  'WereBrownHyenaCosmic 🦴🌌', # Pink Moon
  'WereSnowLeopard 🐆❄️',
  'WereSnowLeopardSnow 🐆❄️❄️', # Pink Moon
  'WereAvian 🦅', # New Moon
  'WereAvianSnow 🦅❄️' # Pink Moon

]

# Each moon phase is assumed to share an equal slice of the lunar cycle.
PHASE_COUNT  = MOON_ROTATIONS.size # 15 total phases
PHASE_LENGTH = MOON_CYCLE_DAYS / PHASE_COUNT # Days per phase

# === Constants and Definitions ===

# Average length of a full lunar cycle (in days)
MOON_CYCLE_DAYS = 29.53

class Calendar
  attr_reader :date

  def initialize
    @date = Date.today
  end

  def gregorian
    @date.strftime('%m/%d/%Y')
  end

  def julian
    jd = @date.jd
    julian_date = Date.jd(jd, Date::JULIAN)
    julian_date.strftime('%m/%d/%Y')
  end

  def julian_primitive
    @date.jd
  end

  def formatted_pst_time
    pst_time = Time.now.getlocal('-07:00')
    pst_time.strftime('%B, %d, %Y - %I:%M:%S %p PST')
  end
end

# Each moon phase is assumed to share an equal slice of the lunar cycle.
PHASE_COUNT  = MOON_ROTATIONS.size # 15 total phases
PHASE_LENGTH = MOON_CYCLE_DAYS / PHASE_COUNT # Days per phase

# === Core Function ===

# Calculate the current moon phase index and return the corresponding phase, species, and were-form.
# Input: date (a Date object)
def current_moon_details(date, moon_rotations, species, were_forms, phase_length)
  # Use a reference new moon date (commonly: January 6, 2000)
  reference_date = Date.new(2000, 1, 6)

  # Calculate the number of days elapsed between the provided date and the reference date.
  days_since_reference = (date - reference_date).to_f

  # Determine the current position within the lunar cycle.
  lunar_position = days_since_reference % MOON_CYCLE_DAYS

  # Calculate which of the 15 phases is current.
  phase_index = (lunar_position / phase_length).floor

  current_phase     = moon_rotations[phase_index % moon_rotations.size]
  current_species   = species[phase_index % species.size]
  current_were_form = were_forms[phase_index % were_forms.size]

  [current_phase, current_species, current_were_form]
end

# === HTML-Generating Functions ===

# Returns an HTML document with the current moon details
def render_current_moon_html(date)
  current_phase, current_species, current_were_form =
    current_moon_details(date, MOON_ROTATIONS, SPECIES, WERE_FORMS, PHASE_LENGTH)

  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Current Moon Phase</title>
      <style>
        body { font-family: Arial, sans-serif; background-color: #f5f7fa; margin: 2rem; }
        .container { max-width: 600px; margin: 0 auto; padding: 2rem; background: #fff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        h1 { text-align: center; }
        p { font-size: 1.2rem; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Current Moon Phase Details</h1>
        <p><strong>Today:</strong> #{date} 📅</p>
        <p><strong>Moon Phase:</strong> #{current_phase} 🌌</p>
        <p><strong>Corresponding Species:</strong> #{current_species} ✨</p>
        <p><strong>Corresponding Were-Form:</strong> #{current_were_form} 🔮</p>
      </div>
    </body>
    </html>
  HTML
end

# Returns an HTML document with the complete 15-phase rotation schedule.
def render_full_schedule_html
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

# === Example Usage for HTML ===

# if __FILE__ == $0
# today = Date.today

# To get HTML for the current moon phase details:
# current_html = render_current_moon_html(today)
# puts current_html

# To get HTML for the complete moon rotation schedule:
#  schedule_html = render_full_schedule_html
#  puts schedule_html
# end

def convert_to_120_second_time_pst
  current_time = TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now)
  total_seconds = current_time.hour * 3600 + current_time.min * 60 + current_time.sec
  seconds_in_120_seconds = 120

  # Calculate the 120-second time
  total_120_seconds = total_seconds / seconds_in_120_seconds
  hours_120_seconds = total_120_seconds / 50
  minutes_120_seconds = (total_120_seconds % 50) * 2

  # Format the output
  format('%02d:%02d', hours_120_seconds, minutes_120_seconds)
end

# Example usage:
# today = Date.today
# puts MoonPhaseDetails.print_details_for_date(today)
# puts MoonPhaseDetails.render_full_schedule_html

# The CGMFS class represents a module for handling various functionalities related to a blog.
class CGMFS
  def get_mdy(date)
    date = Time.parse(date).strftime('%m/%d/%Y')
    date = date.split('/')
    month = date[0].to_i
    day = date[1].to_i
    year = date[2].to_i
    [month, day, year]
  end

  # Example usage:
  # MoonIllumination.age
  # MoonIllumination.percent
  # MoonIllumination.fraction
  # MoonIllumination.emoji
  # MoonIllumination.age(DateTime.new(2017, 1, 1, 0, 0, 0))
  # MoonIllumination.percent(DateTime.new(2017, 1, 1, 0, 0, 0))
  # MoonIllumination.fraction(DateTime.new(2017, 1, 1, 0, 0, 0))
  # MoonIllumination.emoji(DateTime.new(2017, 1, 1, 0, 0, 0))

  def tags2posts(tags_string, user, r)
    parsed = ''
    tags_string.split(', ').each do |tag|
      parsed += "<a href='#{domain_name(r)}/blog/#{user}/tag/#{tag}'>[#{tag}]</a>&nbsp;"
    end
    parsed
  end

  def inflate(string)
    Zlib::Inflate.inflate(string)
  end

  def deflate(string)
    Zlib::Deflate.deflate(string)
  end

  def to_numer_string(words) # to get theoretical numerology number based on any type of character byte...
    reduced_numbers = words.each_byte.sum

    reduced_numbers.to_s.split('').inject(0) do |result, element|
      result.to_i + element.to_i
    end
  end

  def domain_name(r)
    "http://#{SERVER_MAIN_DOMAIN_NAME}"
    # return "https://" + r.host
  end

  def logged_in?(r, user)
    return unless session['user'] != user

    r.redirect "#{domain_name(r)}/blog/login"
  end

  def private_view?(r, user)
    private = false
    if @@line_db[user].pad['blog_database', 'blog_profile_table'][0]['private_view'].nil?
      @@line_db[user].pad['blog_database', 'blog_profile_table'][0]['private_view'] = false
      @@line_db[user].pad['blog_database', 'blog_profile_table'].save_everything_to_files!
    end
    if @@line_db[user].pad['blog_database', 'blog_profile_table'][0]['private_view'] == true && session['user'] != user #  && !LOCAL # add admin access later
      # r.redirect("#{domain_name(r)}/gallery/")
      private = true
      # local_redirect = false
    end
    # elsif @@line_db[user].pad['blog_database',
    #                           'blog_profile_table'][0]['private_view'] == true && session['user'] != user && LOCAL
    # r.redirect("#{SERVER_IP_LOCAL}/gallery/") if LOCAL
    #   redirect = true
    #   local_redirect = true

    r.redirect('/404') if private
  end

  # require_user_login_to_view?(user, r) # redirect to login if not logged in, or redirect to view if logged in
  # private_poster?(user, r) # redirect to blog_view if private, or redirect to blog username if public
  def require_user_login_to_view?(r, user, require_login)
    if session['user'] != user && require_login
      r.redirect("#{domain_name(r)}/blog/login")
    elsif session['user'] == user
      r.redirect("#{domain_name(r)}/blog/#{user}/view")
    end
  end

  def user_logged_in_check?(_r, user)
    logged_in = false
    session['user'] == user
  end

  def private_poster?(user, r)
    return unless @@line_db[user].pad['blog_database', 'blog_profile_table']['private_poster'] == true

    r.redirect "#{domain_name(r)}" unless session['user'] == user && !LOCAL
    r.redirect "#{SERVER_IP_LOCAL}" if session['user'] == user && LOCAL
  end

  def user_failcheck(username, r)
    return if @@line_db.databases.include?(username)

    # @@line_db.new_database!(username)
    # @@line_db[username].pad.new_table!(database_name: "#{username}_database", database_table: "#{username}_table")
    r.redirect "http://#{r.host}:80" if LOCAL
    r.redirect "https://#{r.host}" unless LOCAL
  end

  def redirect_if_id_not_in_db?(id, user, override_param, r)
    redirect = false
    db_id = nil
    begin
      db_id = @@line_db[user].pad['blog_database', 'blog_table'].get(id)
    rescue StandardError
      # redirect = true #r.redirect "https://midscore.io"
    end

    r.redirect "https://#{r.host}blog/#{user}/view" if override_param

    return unless db_id.nil?

    r.redirect "https://#{r.host}/blog/#{user}/view"

    #  override = false
    # end
    # r.redirect("https://midscore.io") if !id && !override
  end

  def family_logged_in?(r)
    return unless $lockdown == true
    return if session['user']
    return if session['password']
    return if session['user'] == 'superadmin'

    nil if r.path == '/blog/login' # Don't redirect if already at login

    r.redirect "#{domain_name(r)}/blog/login"
  end

  # def check_boundaries!(id, user, r)
  #
  #     id = @@line_db[user].pad["blog_database", "blog_table"]
  #     database_size = @@line_db[user].pad["blog_database", "blog_table"].data_arr.size - 1
  #     if id > database_size || id < 0
  #       r.redirect "https://midscore.io"
  #     end
  #   end
  # end
  #

  ########## BLOG section ##########
  #
  hash_branch 'blog' do |r| # ss: screenshot
    family_logged_in?(r) if $lockdown
    @start_rendering_time = Time.now.to_f
    r.hash_branches
    @r = r
    @type = 'blog'

    r.is do
      view('blog/blog', engine: 'html.erb', layout: 'layout.html')
    end

    r.on 'render' do
      r.get do
        @id = r.params['id']
        @user = r.params['user'].to_s
        if @id == 'pin'
          # @pin = @@line_db[@user].pad['blog_database', 'blog_pinned_table'].get(0)
          @body = @@line_db[@user].pad['blog_database', 'blog_pinned_table'].get(0)['blog_post_body'] # get pinned post
          @title = @@line_db[@user].pad['blog_database', 'blog_pinned_table'].get(0)['blog_post_title']

          r.redirect('/404') if @body.nil? # redirect to 404 if no pinned post
        else
          @post = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id.to_i)
          @rendered_type = @post['blog_post_rendered_type']
          @body = @post['blog_post_body']
          @title = @@line_db[@user].pad['blog_database', 'blog_table'].get(0)['blog_post_title']

          r.redirect('/404') if @post.nil?
        end

        if @rendered_type == 'markdown'
          markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, quote: true, strikethrough: true,
                                                                      fenced_code_blocks: true, tables: true, no_intra_emphasis: true, space_after_headers: true, superscript: true, lax_spacing: true, footnotes: true, autolink: true)
          @body = @post['blog_post_body']
          @markdown_body = @post['blog_post_body_markdown'] # save markdown body for later
          @markdown_body = @body.to_s # save markdown body for later
          @body = markdown.render(@markdown_body) if @rendered_type == 'markdown'
          @title = @@line_db[@user].pad['blog_database', 'blog_table'].get(0)['blog_post_title']

        end

        %[
<html>
<title>(#{to_numer_string(@body)}) - #{@title}</title>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link rel="stylesheet" type="text/css" href="#{domain_name(r)}/assets/prism.css">
</head>
<body>

#{@body}
<script src="#{domain_name(r)}/assets/prism.js"></script>
</body>
</html>
]
      end
    end

    r.on 'logout' do
      r.get do
        session['admin'] = nil
        session['user'] = nil
        session['password'] = nil
        r.redirect(domain_name(r))
      end
    end

    r.on 'login' do
      r.is do
        r.get do
          # "test"
          view('blog/login', engine: 'html.erb', layout: 'layout.html')
        end

        r.post do
          # Code to login
          user_name = r.params['blog_user_name'].to_s
          password = r.params['blog_password_name'].to_s
          super_password = 'gUilmon#95458a'
          super_password_params = r.params['super_password'].to_s
          message = ''
          user_name_check = @@line_db[user_name]

          if user_name_check.nil?
            message = 'User does not exist'
          else
            user_password_check = @@line_db['user_blog_database'].pad['user_name_database',
                                                                      'user_password_table'].get(0)
            password_check = user_password_check[user_name]
            if password_check == password && user_name_check == @@line_db[user_name] && (super_password == super_password_params)
              session['user'] = user_name
              session['password'] = password
              r.redirect "/blog/#{user_name}/view"
            else
              message = 'Incorrect information; hit the back button and try again'
            end
          end
          "#{message}"
        end
      end
    end

    r.on 'signup' do
      r.is do
        r.get do
          view('blog/signup', engine: 'html.erb', layout: 'layout.html') # keep signups closed for now; open for our own personal purposes but needs to be closed for the public
          # "Signups are closed; see an admin please."
        end

        r.post do
          # Code to sign up
          user_name = r.params['blog_user_name'].to_s.downcase
          password = r.params['blog_password_name']
          message = 'User creation failed.'
          user_name_check = @@line_db[user_name]
          if user_name_check.nil?
            puts "Creating user: #{user_name}..."
            @@line_db.add_db!(user_name.downcase)
            @@line_db.update_databases
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database', database_table: 'blog_table') # load the blog database
            @@line_db['user_blog_database'].pad.new_table!(database_name: 'user_name_database', database_table: 'user_name_table') # load the user blog database
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database', database_table: 'blog_table')
            puts '...Loading blog_pinned_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_pinned_table')
            puts '...Loading blog_profile_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_profile_table')
            puts '...Loading blog_statistics_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_statistics_table')
            puts '...Loading blog_profile_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_profile_table')
            @@line_db['user_blog_database'].pad['user_name_database', 'user_password_table'].set(0) do |hash|
              hash[user_name] = password
            end
            @@line_db['user_blog_database'].pad['user_name_database', 'user_password_table'].save_everything_to_files!
            puts '...Loading gallery_database + gallery_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'gallery_database', database_table: 'gallery_table')
            puts '...Loading cache system database...'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'cache_system_database', database_table: 'cache_system_table')
            puts '... Loading uwu collections system database...'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'uwu_collections_database', database_table: 'uwu_collections_table')
            puts '... Loading grid collections system database...'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'grid_collections_database', database_table: 'grid_collections_table')
            puts '... Loading containers database ...'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'containers_database', database_table: 'containers_table')
            message = 'User created successfully!'
            # sleep(11)
          elsif !user_name_check.nil? && session['admin'] # should be deprecated... or overriden with *`superadmin`* or `admin` or `root` or `superuser` or `superuseradmin` or `superuseradminroot`
            @@line_db.add_db!(user_name.downcase)
            @@line_db.update_databases
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database', database_table: 'blog_table') # load the blog database
            @@line_db['user_blog_database'].pad.new_table!(database_name: 'user_name_database', database_table: 'user_password_table') # load the user blog database
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database', database_table: 'blog_table')
            puts '...Loading blog_pinned_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_pinned_table')
            puts '...Loading blog_profile_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_profile_table')
            puts '...Loading blog_statistics_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_statistics_table')
            puts '...Loading blog_profile_table.'
            @@line_db[user_name.downcase].pad.new_table!(database_name: 'blog_database',
                                                         database_table: 'blog_profile_table')

            @@line_db['user_blog_database'].pad['user_name_database', 'user_password_table'].set(0) do |hash|
              hash[user_name] = password
            end
            @@line_db['user_blog_database'].pad['user_name_database', 'user_password_table'].save_everything_to_files!
            message = 'User created successfully! Admin override.'
            # sleep(11)
          end
          # r.redirect "https://#{r.host}/blog/login"
          puts Dir.pwd
          folder_path = '/home/midscore_io/db'

          # Define the location where the zip file will be placed
          zip_location = '/home/midscore_io/db_backup'

          # Create the zip file name
          zip_file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}_#{File.basename(folder_path)}.zip"

          # Create the system call to zip the folder
          # system("zip -r #{zip_location}/#{zip_file_name} #{folder_path}")
          # sleep(11)
          message
        end
      end
    end

    # for something like, "aritywolf", pre-emptively making dynamicable blog posters.
    r.on String do |user|
      user_failcheck(user, r)

      #  require_user_login_to_view?(user, r) # redirect to login if not logged in, or redirect to view if logged in
      #  private_poster?(user, r) # redirect to blog_view if private, or redirect to blog username if public

      r.is do
        r.redirect("#{domain_name(r)}/blog/#{user}/view")
      end

      r.on 'pin' do
        r.is do
          logged_in?(r, user)
          r.post do
            @@line_db[user].pad['blog_database', 'blog_pinned_table'].set(0) do |hash|
              hash['blog_post_title'] = r.params['blog_post_title'].to_s
              # hash["blog_post_content"] = r.params["blog_post_content"]
              hash['blog_post_author'] = r.params['blog_post_author']
              hash['blog_post_tags'] = r.params['blog_post_tags'].to_s
              hash['blog_post_date'] = r.params['blog_post_date'].to_s
              hash['blog_post_body'] = r.params['blog_post_body'].to_s
              hash['blog_post_comments'] = r.params['blog_post_comments']
              hash['blog_post_status'] = r.params['blog_post_status']
              hash['blog_status_locked'] = r.params['blog_status_locked']
              # hash["blog_post_id"] = r.params["blog_post_id"]
            end
            @@line_db[user].pad['blog_database', 'blog_pinned_table'].save_everything_to_files!
            r.redirect("#{domain_name(r)}/blog/#{user}/pin")
          end
          r.get do
            @user = user
            @r = r
            @type = user_logged_in_check?(@r, @user)
            #     @@line_db[db].pad.new_table!(database_name: "blog_database", database_table: "blog_pinned_table")

            @title = "#{@user} pinned posts"
            @post = @@line_db[@user].pad['blog_database', 'blog_pinned_table'][0]
            view('blog/pin', engine: 'html.erb', layout: 'layout.html')
          end
        end
      end

      r.on 'tag' do
        r.is String do |tag|
          r.get do
            @user = user
            @r = r
            @tag = tag.gsub(/%20/, ' ')
            @title = "#{@user} with tag #{@tag} in posts"
            @posts = @@line_db[@user].pad['blog_database', 'blog_table'][:all]
            @tagged_posts = []

            @posts.each_with_index do |post, index|
              next unless post['blog_post_tags'] && post['blog_post_tags'].include?(@tag)

              _post = index
              # parse title, descriptions (optional), and tags
              @tagged_posts << _post
              # break
            end
            @tagged = @tagged_posts.map do |id|
              @@line_db[@user].pad['blog_database', 'blog_table'].get(id)
            end
            #  @post = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)

            view('blog/tag', engine: 'html.erb', layout: 'layout.html')
          end
        end
      end

      r.on 'edit' do
        logged_in?(r, user)
        r.is Integer do |id|
          redirect_if_id_not_in_db?(id, user, r.params['override'], r)
          r.get do
            @id = id
            @r = r
            @user = user
            @post = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)
            @markdown_body = @post['blog_post_body_markdown']
            @body = @markdown_body || @post['blog_post_body']
            # @body = @markdown_body if @markdown_body
            @title = "Edit Blog Post - ##{@id} - #{@user}"
            # markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, quote: true, strikethrough: true, fenced_code_blocks: true, tables: true, no_intra_emphasis: true, space_after_headers: true, superscript: true, lax_spacing: true, footnotes: true, autolink: true)
            # @body = @body
            # @body = @markdown_body if @markdown_body
            #  hash['blog_post_rendered_type'] = r.params['rendered_type'].to_s  # add rendering type

            #  hash['timestamp'] = TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now).to_s
            # #endhash['blog_post_rendered_type'] = @rendered_type.to_s # add rendering type
            @rendered_type = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)['blog_post_rendered_type']
            @@line_db[@user].pad['blog_database', 'blog_table'].save_everything_to_files!
            case @rendered_type
            when 'wysiwyg'
              @view = 'blog/edit'
              @rendered_type = 'wysiwyg'
            when 'markdown'
              @view = 'blog/edit_markdown'
              @rendered_type = 'markdown'
            when 'html'
              @view = 'blog/edit_html'
              @rendered_type = 'html'
            # else
            #   view('blog/new', engine: 'html.erb', layout: 'layout.html')
            else
              @view = 'blog/edit'
              @rendered_type = 'wysiwyg'
            end

            folder_path = '/home/midscore_io/db'

            # Define the location where the zip file will be placed
            zip_location = '/home/midscore_io/db_backup'

            # Create the zip file name
            zip_file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}_#{File.basename(folder_path)}.zip"

            # Create the system call to zip the folder
            # system("zip -r #{zip_location}/#{zip_file_name} #{folder_path}")
            view(@view, engine: 'html.erb', layout: 'layout.html')
          end
        end

        r.post do
          # for post edits, check to see if markdown is enabled
          # when you first post, you are sending markdown, but when you edit, you are sending html
          # so, if you are editing, you need to convert the html to markdown
          @user = session['user']
          @r = r
          @_params = {}
          valid = true
          message = ''
          # Code to edit a blog post
          @_params['blog_post_title'] = r.params['blog_post_title'].to_s
          @_params['blog_post_body'] = r.params['blog_post_body']
          @_params['blog_post_tags'] = r.params['blog_post_tags'].to_s
          @_params['blog_post_date'] = r.params['blog_post_date'].to_s
          @_params['blog_post_author'] = r.params['blog_post_author'].to_s
          #  @_params['blog_post_category'] = r.params['blog_post_category'].to_s
          @_params['blog_post_body_markdown'] = r.params['blog_post_body_markdown'].to_s
          @_params['blog_post_comments'] = r.params['blog_post_comments'].to_s
          @_params['blog_post_status'] = r.params['blog_post_status'].to_s
          @_params['blog_status_locked'] = r.params['blog_status_locked'].to_s
          @rendered_type = @_params['rendered_type'] = r.params['rendered_type'].to_s
          @_params['id'] = r.params['id'].to_s
          parse_blog_status = r.params['blog_status_locked'].to_s
          if parse_blog_status == '0'
            @_params['blog_status_locked'] = false
          elsif parse_blog_status == '1'
            @_params['blog_status_locked'] = true
          end
          if @_params['blog_post_title'] != '' && @_params['blog_post_body'] != '' && @_params['blog_post_tags'] != '' && @_params['blog_post_date'] != '' && @_params['blog_post_author'] != ''
            valid = true
          else
            valid = false
          end
          @body = @_params['blog_post_body']
          if @rendered_type == 'markdown'
            markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, quote: true, strikethrough: true,
                                                                        fenced_code_blocks: true, tables: true, no_intra_emphasis: true, space_after_headers: true, superscript: true, lax_spacing: true, footnotes: true, autolink: true)
            @body = @_params['blog_post_body_markdown']
            @markdown_body = @body.to_s # save markdown body for later
            @body = markdown.render(@body) if @rendered_type == 'markdown'

          end

          if valid
            @@line_db[@user].pad['blog_database', 'blog_table'].set(@_params['id'].to_i) do |hash|
              hash['blog_post_title'] = @_params['blog_post_title']
              hash['blog_post_body'] = @body # the rendered html
              # the markdown body
              hash['blog_post_body_markdown'] = @_params['blog_post_body_markdown'] if @rendered_type == 'markdown'
              hash['blog_post_tags'] = @_params['blog_post_tags']
              hash['blog_post_date'] = @_params['blog_post_date']
              hash['blog_post_author'] = @_params['blog_post_author']
              # hash['blog_post_category'] = @_params['blog_post_category']
              hash['blog_post_comments'] = @_params['blog_post_comments']
              hash['blog_post_status'] = @_params['blog_post_status']
              hash['blog_status_locked'] = @_params['blog_status_locked']
              hash['id'] = @_params['id']
            end
            @@line_db[@user].pad['blog_database', 'blog_table'].save_everything_to_files!

            # "done"
            # id = @_params["id"].to_i
            #  "id: #{r.params["id"]}"

            folder_path = '/home/midscore_io/db'

            # Define the location where the zip file will be placed
            zip_location = '/home/midscore_io/db_backup'

            # Create the zip file name
            zip_file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}_#{File.basename(folder_path)}.zip"

            # Create the system call to zip the folder
            # system("zip -r #{zip_location}/#{zip_file_name} #{folder_path}")
            r.redirect("/blog/#{@user}/edit/#{@_params['id']}")
          end
        end
      end

      r.on 'delete' do
        logged_in?(r, user)
        r.is Integer do |id|
          r.get do
            @r = r
            @user = user
            @id = id
            @title = "LOCK Blog Post - #{@user} - #{@id}"
            # Code to delete a blog post
            @@line_db[@user].pad['blog_database', 'blog_table'].set(id) do |hash|
              hash['blog_status_locked'] = !hash['blog_status_locked']
              @locked = hash['blog_status_locked']
            end
            @@line_db[@user].pad['blog_database', 'blog_table'].save_everything_to_files!
            # "#{@locked}"

            folder_path = '/home/midscore_io/db'

            # Define the location where the zip file will be placed
            zip_location = '/home/midscore_io/db_backup'

            # Create the zip file name
            zip_file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}_#{File.basename(folder_path)}.zip"

            # Create the system call to zip the folder
            # system("zip -r #{zip_location}/#{zip_file_name} #{folder_path}")
            r.redirect("/blog/#{user}/delete")
          end
        end

        r.get do
          @r = r
          @title = "Delete Blog Post - #{@user}"
          @user = user
          @posts = @@line_db[@user].pad['blog_database', 'blog_table'].data_arr
          view('blog/delete', engine: 'html.erb', layout: 'layout.html')
        end
      end

      r.is 'list' do
        r.get do
          @user = user
          @r = r
          @title = "List of Blog Posts - #{@user}"
          @posts = @@line_db[@user].pad['blog_database', 'blog_table'].data_arr
          view('blog/list', engine: 'html.erb', layout: 'layout.html')
        end
      end

      r.is 'new' do
        logged_in?(r, user)
        r.get do
          @user = user
          @r = r
          @title = 'New Blog Post'
          @possible_rendering_types = %w[wysiwyg markdown html]
          @rendered_type = @r.params['rendered_type'].to_s
          @rendered_type = 'wmarkdown' if @rendered_type == ''
          @rendered_type = 'markdown' unless @possible_rendering_types.include?(@rendered_type)
          @view = case @rendered_type
                  when 'wysiwyg'
                    'blog/new_wysiwyg'
                  when 'markdown'
                    'blog/new_markdown'
                  when 'html'
                    'blog/new_html'
                  else
                    'blog/new'
                  end
          # if @rendered_type == 'wysiwyg'

          view("#{@view}", engine: 'html.erb', layout: 'layout.html')
        end

        r.post do
          @user = user
          @r = r
          valid = false
          message = ''
          @_params = {}

          #  "test"
          # Code to create a new blog post

          @latest_id = @@line_db[@user].pad['blog_database', 'blog_table'].latest_id
          @_params['blog_post_title'] = r.params['blog_post_title'].to_s
          # @_params['blog_post_title'] = r.params['blog_post_title'].to_s
          @_params['blog_post_body'] = r.params['blog_post_body'].to_s
          @_params['blog_post_tags'] = r.params['blog_post_tags'].to_s
          @_params['blog_post_date'] = r.params['blog_post_date'].to_s
          @_params['blog_post_author'] = r.params['blog_post_author'].to_s
          @_params['blog_post_body_markdown'] = r.params['blog_post_body_markdown'].to_s
          # @_params['blog_post_category'] = r.params['blog_post_category'].to_s
          @_params['blog_post_comments'] = r.params['blog_post_comments'].to_s
          @_params['blog_post_status'] = r.params['blog_post_status'].to_s
          @_params['blog_status_locked'] = false
          if @_params['blog_post_title'] != '' && (@_params['blog_post_body'] != '' || @_params['blog_post_body_markdown'] != '') && @_params['blog_post_tags'] != '' && @_params['blog_post_date'] != '' && @_params['blog_post_author'] != '' && @_params['blog_post_category'] != ''
            valid = true
          else
            valid = false
          end

          if valid

            @body = r.params['blog_post_body'].to_s
            # choose renderer between wysiwyg, markdown, or html
            # markdown -> html
            @possible_rendering_types = %w[wysiwyg markdown html]
            @rendered_type = r.params['rendered_type'].to_s # need to pass rendered_types param from get new to post new
            @rendered_type = 'wysiwyg' if @rendered_type == ''
            @rendered_type = 'wysiwyg' unless @possible_rendering_types.include?(@rendered_type)
            if @rendered_type == 'markdown'
              markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, quote: true, strikethrough: true,
                                                                          fenced_code_blocks: true, tables: true, no_intra_emphasis: true, space_after_headers: true, superscript: true, lax_spacing: true, footnotes: true, autolink: true)
              @body = r.params['blog_post_body_markdown'].to_s
              @markdown_body = @body.to_s # save markdown body for later
              @body = markdown.render(@markdown_body)

            end

            # wysiwyg -> html
            # html -> html

            @@line_db[@user].pad['blog_database', 'blog_table'].add do |hash|
              hash['blog_post_title'] = @_params['blog_post_title']
              hash['blog_post_body'] = @body
              hash['blog_post_body_markdown'] = @markdown_body if @rendered_type == 'markdown'
              hash['blog_post_tags'] = @_params['blog_post_tags']
              hash['blog_post_date'] = @_params['blog_post_date']
              hash['blog_post_author'] = @_params['blog_post_author']
              hash['blog_post_comments'] = @_params['blog_post_comments']
              hash['blog_post_status'] = @_params['blog_post_status']
              hash['id'] = @latest_id
              hash['blog_status_locked'] = @_params['blog_status_locked']
              hash['blog_post_rendered_type'] = @rendered_type.to_s # add rendering type
              hash['timestamp'] = TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now).to_s
            end
            @@line_db[@user].pad['blog_database', 'blog_table'].save_everything_to_files!
            r.redirect "/blog/#{@user}/view/#{@latest_id}"
          else
            message = "Please fill out all fields. Fields not filled out: #{@_params}"
          end
        end
      end

      r.on 'private_toggle' do
        r.is do
          r.get do
            @username_session = session['user']
            if @username_session == user
              @@line_db[user].pad['blog_database', 'blog_profile_table'].set(0) do |hash|
                hash['private_view'] = (hash['private_view'].nil? || !hash['private_view'])
              end
              puts Dir.pwd
              folder_path = '/home/midscore_io/db'

              # Define the location where the zip file will be placed
              zip_location = '/home/midscore_io/db_backup'

              # Create the zip file name
              zip_file_name = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}_#{File.basename(folder_path)}.zip"

              # Create the system call to zip the folder
              # system("zip -r #{zip_location}/#{zip_file_name} #{folder_path}")
              @@line_db[user].pad['blog_database', 'blog_profile_table'].save_everything_to_files!
            end
            r.redirect("#{domain_name(r)}/blog/#{user}/view")
          end
        end
      end

      r.on 'view' do
        private_view?(r, user)
        # make a view based on markdown, html, or wysiwyg; if markdown marked, derender html in markdown
        # markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, quote: true, strikethrough: true, fenced_code_blocks: true, tables: true, no_intra_emphasis: true, space_after_headers: true, superscript: true, lax_spacing: true, footnotes: true, autolink: true)
        # @body = markdown.render(@body)
        # get the blog statistic table's entry for this user
        # @@line_db[db].pad.new_table!(database_name: "blog_database", database_table: "blog_statistics_table")
        r.is do
          r.get do
            @user = user
            @session = session
            # @@line_db[@user]
            @pin = @@line_db[user].pad['blog_database', 'blog_pinned_table'][0]
            @r = r
            @title = "All Blog Posts by #{@user}"
            @posts = @@line_db[@user].pad['blog_database', 'blog_table'][:all]
            @tagged_posts = []
            @tagged = []
            @tags = @posts.map do |post|
                      post['blog_post_tags'].split(', ') if post['blog_post_tags']
                    end.flatten.uniq[0..-2]
            @desc_view = r.params['desc']
            # @page_views = @@line_db[@user].pad['blog_database', 'blog_statistics_table'][0]['page_views']
            # @page_views = 0 if @page_views == nil
            # add page views to the database per post

            # post['page_views'] = 0 if post['page_views'] == nil
            # post['page_views'] += 1
            @@line_db[@user].pad['blog_database', 'blog_statistics_table'].set(0) do |hash|
              #  break if post_index > @@line_db[@user].pad['blog_database', 'blog_statistics_table'].latest_id - 1
              if hash['page_views'].nil?
                hash['page_views'] = 0
              else
                hash['page_views'] += 1
              end
              @page_views = hash['page_views']
            end
            @@line_db[@user].pad['blog_database', 'blog_statistics_table'].save_partition_to_file!(0)

            # @tagged =  @tagged_posts.map do |id|
            #     @@line_db[@user].pad['blog_database', 'blog_table'].get(id)
            #    end
            # "#{@@line_db[@user]}"

            @desc_posts = r.params['desc']
            @reversed_posts = r.params['reverse']
            # is nil in view_all.erb.html out of pass by reference convention...
            @posts = @posts.reverse if @reversed_posts.nil?

            # get the blog post rendered type, and determine whether to render in plaih html or markdown
            view('blog/view_all', engine: 'html.erb', layout: 'layout.html')
            # "#{@page_counts}"
          end
        end

        r.is Integer do |id|
          private_view?(r, user)
          redirect_if_id_not_in_db?(id, user, r.params['override'], r)
          r.get do
            @id = id
            @user = user
            @r = r
            @rendered_type = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)['blog_post_rendered_type']
            @parse_markdown_to_html = false
            @parse_markdown_to_html = true if @rendered_type == 'markdown'
            begin
              @id_check = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)['id']
              'This entry does not exist in the database.' if @id_check.nil?
              if @id_check && @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)['blog_status_locked'] == true
                'This entry is locked.'
              end
            rescue StandardError
              'Something went wrong or was tampered with. As a word of caution, this is a beta version of the blog system.'
            end
            @post = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)
            @body = @post['blog_post_body']
            # @markdown_body = @@line_db[@user].pad['blog_database', 'blog_table'].get(@id)['blog_post_body_markdown'] if @parse_markdown_to_html == true
            # @body = # @markdown_body if @parse_markdown_to_html == true
            @title = "Blog Post - #{@post['blog_post_title'] || 'Untitled...'} - #{@user}(#{@id}) - #{@post['blog_post_date']}"
            # @@line_db[@user].pad['blog_database', 'blog_statistics_table'].set(0) do |hash|
            #  hash['page_views'] = @page_views + 1
            @@line_db[@user].pad['blog_database', 'blog_statistics_table'].set(0) do |hash|
              #  break if post_index > @@line_db[@user].pad['blog_database', 'blog_statistics_table'].latest_id - 1
              if hash['page_views'].nil?
                hash['page_views'] = 0
              else
                hash['page_views'] += 1
              end
              @page_views = hash['page_views']
            end
            # entry = @@line_db[@user].pad['blog_database', 'blog_statistics_table'].latest_id - 1
            # partition_entry =
            @@line_db[@user].pad['blog_database', 'blog_statistics_table'].save_partition_to_file!(0)
            # @page_views += 1
            # calculate page views per post

            # GET LATEST entry id in the database, run it through get to get the latest partition to save, then save up to that partition location
            #

            # @@line_db[@user].pad['blog_database', 'blog_statistics_table'].save_partition_to_files!(@entries_to_save)

            ### Efficient save method
            # @@line_db[@user].pad['blog_database', 'blog_statistics_table'].save_everything_to_files!
            ### INEFFICIENT save method
            # @@line_db[@user].pad['blog_database', 'blog_statistics_table'].save_everything_to_files!
            #

            view('blog/view', engine: 'html.erb', layout: 'layout.html')
          end
        end

        r.is String, Integer, Integer, Integer do |month, day, year, _time|
          r.get do
            @title = 'Blog Post'
            @user = user
            @r = r
            @post = find_post(month, day, year)
            view('blog/view_dates', engine: 'html.erb', layout: 'layout.html')
          end
        end
        # r route for
      end
    end
  end
end

def find_post(month, day, year)
  # Code to retrieve the blog post based on the month, day, and year
end

# Q: how to merge git changes?
# A: git merge <branch_name>
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/MethodLength
# rubocop:enable Layout/LineLength
# rubocop:enable Style/RedundantInterpolation
