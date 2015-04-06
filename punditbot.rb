require 'csv'
require 'yaml'
class JeremyMessedUpError < StandardError; end
#TODO: pre-parse templates, phrases into rearrangeable VPs, PPs, (e.g. Without Iowa, GOP hasn't won the White House since 1948 vs. Since 1948, GOP hasn't won the White House.)
#TODO: use a "microplanner" or other NLG techniques for managing capitalization, inflection, etc.

datasets = [] # maybe these are rails models?


TEMPLATES = [
  "Since <start_year>, the <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> in which <data_claim><ending>[.;]",
  "Since <start_year>, <time_phrase_2> <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]",
  "The <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> since <start_year> in which <data_claim><ending>[.;]",
  "<time_phrase_2> since <start_year> when <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]"
]
POLARITIES = [true, false]
TOO_RECENT_TO_CARE_CUTOFF = 1992 #if the claim is false twice after (including) 1992, then skip the correlation
 
POLITICS_VERB_PHRASES = { "won the [White House; presidency]" => {race: :pres, won: false, change: false},
                          # "hasn't controlled the Senate" => {},
                          # "hasn't controlled the House" => {},
                          # "has kept or won control of Senate/House" => {},
                          # "has won control of the Senate/House." => {},
                          # "has picked up Senate/House seats" => {},
                          # "has lost Senate/House seats" => {},
                          #TODO: "hasn't won <state>'s electoral votes"
                          #TODO: "hasn't won both of <state>'s Senate seats"
                          #TODO: "hasn't won the White House without <state>",
                        }

class Subj
  attr_reader :word
  def initialize(word, number)
    @word = word
    @number = number
  end

  def plural?
    @number != 0
  end

  def singular?
    @number == 0
  end

  def to_s
    @word
  end
end

class Verb
  # it's what you do
  def initialize(i)
    if i.size == 2
      raise ArgumentError unless i.all?{|p| p.size == 3}
      @by_number = i.map{|frag| VerbFragment.new(frag)}
      @by_person = i.transpose.map{|frag| VerbFragment.new(frag)}
    elsif i.size == 3
      raise ArgumentError unless i.all?{|n| n.size == 2}
      @by_person = i.map{|frag| VerbFragment.new(frag)}
      @by_number = i.transpose.map{|frag| VerbFragment.new(frag)}
    else 
      raise ArgumentError, "ur verbin wrong"
    end
  end

  def +(str)
    self.class.new(@by_person.map{|frag| (frag + str).to_a })
  end

  def person(p)
    raise ArgumentError, "#{p}th person doesn't exist in English" unless [1,2,3].include?(p)
    @by_person[p-1]
  end
  def number(n) # like I have seven swans, call number(7)
    raise ArgumentError, "there is no grammatical number `#{n}'" unless n.is_a?(Fixnum) || n.is_a?(Float)
    @by_number[n == 1 ? 0 : 1]
  end

  def to_s
    person(3).number(1) # TODO, fix later.
  end
end

class VerbFragment < Verb
  def initialize(i)
    raise ArgumentError, "#{i.inspect} must be one-dimensional" unless i.all?{|q| q.respond_to? :gsub}
    @by_person = @by_number = i
  end
  def +(str)
    self.class.new(@by_person.map{|n| n + str })
  end
  def to_a
    @by_number
  end
end

# TODO: this verb system is broken
# fix it.
# probably needs a VerbFragment class that, if number() or person() is called, returns a string

VERBS = {
  'has' => Verb.new([['have', 'have'], ['have', 'have'], ['has', 'have']]) #LOLOLOL
}

class Party
  attr_reader :name, :alt_names, :wikipedia_symbol
  def initialize(name, alt_names, wikipedia_symbol)
    @name = name
    @alt_names = alt_names
    @wikipedia_symbol = wikipedia_symbol
  end

  def names
    "[#{(alt_names + [name]).join(';')}]"
  end
end

PARTIES = [
  Party.new(Subj.new("Democratic Party", 1), [Subj.new("Dems", 2), Subj.new("Democrats", 0)], 'D'), 
  Party.new(Subj.new("Republican Party", 1), [Subj.new("G.O.P.", 1), Subj.new("Republicans", 1)], 'R')
]

class Dataset
  attr_reader :name, :noun, :min_year, :data, :source
  def initialize(obj) 
    #TODO: take a root-level object from correlates.yml
    # create a dataset object from it
    # Notably: only one dataset object per spreadsheet
    # - this means a column from a dataset with one column is more likely to be used than a 
    #   column from a dataset with many; this is intentional. We're randomly choosing datasets (for now).

    # read in CSV, process (e.g. numerics get gsubbed out non numeric chars.)
    # keep year column as string
    @csv = CSV.read("data/correlates/#{obj["filename"]}", {:headers => true})
    @year_column_header = obj["year_column_header"]
    @min_year = @csv.map{|row| row[@year_column_header] }.sort.first
    @data_columns = obj["data_columns"]
    @source = obj["source"]
  end

  def cleaners
    { 
      "numeric"     => lambda{|n| n.gsub(/[^\d]/, '').to_i },
      "categorical" => lambda{|x| x}
    }
  end

  def get_data!
    #randomly give a column's data
    return @data unless @data.nil?
    column = @data_columns.sample
    puts column.inspect
    @noun  = column["noun"]
    type = column["type"] || "numeric"
    @data = Hash[*@csv.map{|row| [row[@year_column_header], cleaners[type].call(row[column["header"]])] }.flatten]
  end
end

class Prediction
  attr_reader :prediction, :template
  attr_accessor :data
  def initialize(template)
    @prediction = template
    @template = template
    @data = {}
  end

  def templatize!
    @template.scan(/<([a-zA-Z0-9_]+)>/).map(&:first).each do |template_phrase|
      puts "Missing key: #{template_phrase}" unless @data.has_key? template_phrase
      puts @data[template_phrase].to_s.inspect
      @prediction.gsub!("<#{template_phrase}>", @data[template_phrase].to_s)
    end
  end

  def resolve_options!
    # N.B. a rephrase can be empty if the phrase is optional.

    #TODO: figure out how to do rephrases in a way that's smart about 140 chars
    @prediction.scan(/\[([^\]]*)\]/).map(&:first).each do |rephrases|
      rephrase = rephrases.split(';', -1).map(&:strip).sample
      @prediction.gsub!("[#{rephrases}]", rephrase)
    end
  end

  def capitalize!
    @prediction = @prediction[0].capitalize + @prediction[1..-1]
  end

  def verify!
    raise JeremyMessedUpError, @prediction if @prediction.include?("<") || @prediction.include?("[")
  end


  def to_s
    capitalize!
    verify!
    @prediction
  end

  def inspect
    capitalize!
    verify!
    "\"#{@prediction} (#{@prediction.size} chars)\""
  end
end

class PunditBot
  def initialize
    process_csv!
    @parties = PARTIES
    @datasets = YAML.load_file('data/correlates.yml')
  end
  def vectorize_politics_verb_phrase(politics_verb_phrase, party)
    phrase_meta =  POLITICS_VERB_PHRASES[politics_verb_phrase]
    state  = phrase_meta[:state] || "USA"
    race   =  phrase_meta[:race] || :pres
    won    =  phrase_meta[:race] || :pres
    change =  phrase_meta[:race] || :pres
    victors = @elections[race][state]
    tf_vector = Hash[*@election_years.map{|year| [year, victors[year].match(/[A-Z]+/).to_s == party.wikipedia_symbol]}.flatten]
    puts "tf_vector: #{tf_vector}"
    tf_vector 
  end

  def get_a_dataset!
    @dataset = Dataset.new(@datasets.sample)
    @dataset.get_data!
  end

  def find_data(hash_of_results)
    # for our data sets, find the earliest election year where the data condition matches that year's value in the vector_to_match every year or all but once.
    raise JeremyMessedUpError unless hash_of_results.is_a? Hash
    # like {2012 => true, 2008 => true, 2004 => false} if we're talking about Dems winning WH

    # datasets must all look like this {2004 => 5.5, 2008 => 5.8, 2012 => 8.1 }
    get_a_dataset! # seems more exciting with the ! at the end, no?


    trues, falses = @dataset.data.to_a.partition.each_with_index{|val, idx| hash_of_results[val[0]] } #TODO: factor out; but something like it is used in predicates
    # predicates need a lambda and an English template
    predicates = [
      { l: lambda{|x, _|  x > trues.map{|a, b| b}.min }, 
        phrase: "<noun> was greater than #{trues.map{|a, b| b}.min}" }, # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
      
      { l: lambda{|x, _| x < trues.map{|a, b| b}.max }, 
        phrase: "<noun> was less than #{trues.map{|a, b| b}.max}" }, # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,


      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.last.to_i.even? }, 
        phrase: "<noun> ended in an even number",
      }, 
      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.last.to_i.odd? }, #TODO: figure out how to get rid of these dupes (odd/even)
        phrase: "<noun> ended in an odd number",
      }, 
      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.first.to_i.even? }, 
        phrase: "<noun> started with an even number",
      }, 
      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.first.to_i.odd? }, 
        phrase: "<noun> started with an odd number",
      }, 
      { l: lambda{|x, _| x.even? }, 
        phrase: "<noun> is an even number",
      }, 
      { l: lambda{|x, _| x.odd? }, 
        phrase: "<noun> is an odd number",
      }, 


      { l: lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).even? }, 
        phrase: "<noun>'s digits add up to an even number",
      }, 
      { l: lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).odd? }, 
        phrase: "<noun>'s digits add up to an odd number",
      }, 
      { l: lambda{|x, yr| x > @dataset.data[(yr.to_i-1).to_s] }, 
        phrase: "<noun> grew from the previous year",
      }, 
      { l: lambda{|x, yr| x < @dataset.data[(yr.to_i-1).to_s] }, 
        phrase: "<noun> declined from the previous year",
      }, 
    ]

    result_needs_better_name = nil
    predicates.product(POLARITIES).shuffle.find do |pred, polarity|
      # find the most recent two years where the pattern is broken
      exceptional_year = nil
      start_year = nil
      @election_years.reverse.each_with_index do |yr, idx|
        next if yr < (@dataset.min_year.to_i - 1).to_s
        raise JeremyMessedUpError unless idx > 0 || yr != "2014" 
        # find the second year for which the pattern doesn't fit
        if pred[:l].call(@dataset.data[yr], yr) == (hash_of_results[yr] == polarity) # if this year matches the pattern
          # do nothing
        elsif exceptional_year.nil? # if this is the first year that doesn't match the pattern
          exceptional_year = yr
        else #this is the second year that doesn't match the pattern
          start_year = yr
          break
        end
      end
      start_year = @dataset.min_year if start_year.nil?
      puts "Start year: #{start_year}"
      if start_year > TOO_RECENT_TO_CARE_CUTOFF.to_s
        false
      else
        result_needs_better_name = {
          data_claim: pred[:phrase].gsub('<noun>', @dataset.noun),
          start_year: start_year, #never nil
          exceptional_year: exceptional_year, # maybe nil
          polarity: polarity #TODO: make this depend on the predicate
        }
        break
      end
    end

    puts "Results: #{result_needs_better_name}"
    result_needs_better_name
  end

  def generate_prediction
    prediction = Prediction.new(TEMPLATES.sample) # cloned by prediction
    prediction.data["party"] = (party = @parties.sample).names
    politics_verb_phrase = prediction.data["politics_verb_phrase"] = POLITICS_VERB_PHRASES.keys.sample
    party_wins_vector = vectorize_politics_verb_phrase(politics_verb_phrase, party)

    data = find_data(party_wins_vector)
    #TODO choose between when ... always/never
    # and                in every/no ... (nothing)
    # e.g. * in every year fake unemployment ended in an even number, the Republican Party has always won the white house.
    # e.g.   when fake unemployment ended in an even number, the Republican Party has always won the white house.
    return nil if data.nil?
    if data[:exceptional_year]
      prediction.data['ending'] = ", [except; save] #{data[:exceptional_year]}" #note initial space
      prediction.data['time_phrase_1'] = VERBS['has'] + "#{data[:polarity] ? '' : ' not'}"
      prediction.data['time_phrase_2'] = "in #{data[:polarity] ? 'every' : 'any'} year"
    else
      prediction.data['ending'] = ''
      prediction.data['time_phrase_1'] = VERBS['has'] + " #{data[:polarity] ? 'always' : 'never'}"
      prediction.data['time_phrase_2'] = "in #{data[:polarity] ? 'every' : 'any'} year"
    end
    prediction.data['start_year'] = data[:start_year]
    prediction.data['data_claim'] = data[:data_claim]
    puts prediction.data.inspect

    prediction.templatize!
    prediction.resolve_options!
    prediction.capitalize!

    prediction
    ## TODO: if there's room, replace [] things, otherwise, erase them
    ## fix capitalization
  end

  def process_csv!
    # csv is download of source page, with source row added (linking to Wikipedia)
    csv = CSV.read('data/elections/List_of_United_States_presidential_election_results_by_state.csv', {:headers => true})
    @election_years = csv.headers.select{|h| h && h.match( /\d{4}/)}
    

    usa_winner = {"State" => "USA", "Source" => csv.find{|row| row["State"] == "New York" }["Source"]}
    ["New York", "South Carolina", "Georgia" ].each do |colony| # these happen to have voted for a winner every year
      @election_years.each{|yr| usa_winner[yr] = csv.find{|row| row["State"] == colony}[yr] if (csv.find{|row| row["State"] == colony}[yr] || '').match(/^\*.+\*$/) }
    end
    #TODO: are there two states where one has voted for the winner every election?
    @elections = {:pres => {}}
    csv.each{|row| @elections[:pres][row["State"]] = row.to_hash }
    @elections[:pres][usa_winner["State"]] = usa_winner
  end
end

puts (10.times.to_a.map do |i|
  pundit = PunditBot.new
  prediction = pundit.generate_prediction
  prediction
end.compact.map(&:to_s).uniq)

# Since 1975, in every year fake unemployment had declined over the past year, the GOP has  won the presidency save 2012.
# Since 1975, in any year fake unemployment was greater than 2.2, the Republicans has never won the White House.
# Since 1975, the Democrats has not won the White House in any year in which fake unemployment had declined over the past year except 2012.
# Since 1975, in every year fake unemployment ended in an odd number, the Dems has always won the presidency
# Since 1975, the Republican Party has not won the White House in any year in which fake unemployment had grown over the past year save 2012.
# Since 1975, in any year fake unemployment had grown over the past year, the GOP has not won the White House except 2012
# Since 1975, in every year fake unemployment had declined over the past year, the Republicans has  won the White House save 2012.
# Since 1975, the Democratic Party has not won the White House in any year in which fake unemployment had declined over the past year save 2012
# Since 1975, in every year fake unemployment had grown over the past year, the Dems has  won the presidency except 2012
# Since 1975, the Republican Party has always won the presidency in every year in which fake unemployment ended in an even number.
