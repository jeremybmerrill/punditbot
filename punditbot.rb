require 'csv'
class JeremyMessedUpError < StandardError; end
#TODO: pre-parse templates, phrases into rearrangeable VPs, PPs, (e.g. Without Iowa, GOP hasn't won the White House since 1948 vs. Since 1948, GOP hasn't won the White House.)
#TODO: use a "microplanner" or other NLG techniques for managing capitalization, inflection, etc.

datasets = [] # maybe these are rails models?

#TODO: rephrase options: find semicolon separated lists, pick one.

TEMPLATES = [
  "Since <start_year>, the <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> in which <data_claim><ending>[.;]",
  "Since <start_year>, <time_phrase_2> <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]",
  "The <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> since <start_year> in which <data_claim><ending>[.;]",
  "<time_phrase_2> since <start_year> <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]"
]
POLARITIES = [true, false]
 
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
  #TODO: deal with rephrase options' number :-/
end

class Dataset
  #http://data.bls.gov/timeseries/LNU04000000?years_option=all_years&periods_option=specific_periods&periods=Annual+Data
end

class Prediction
  attr_reader :prediction, :template
  attr_accessor :data
  def initialize(template)
    @template = template
    @prediction = template.clone
    @data = {}
  end

  def templatize!
    @template.scan(/<([a-zA-Z0-9_]+)>/).map(&:first).each do |template_phrase|
      puts "Missing key: #{template_phrase}" unless @data.has_key? template_phrase
      @prediction.gsub!("<#{template_phrase}>", @data[template_phrase].to_s)
    end
  end

  def resolve_options!
    #notably, a rephrase can be empty
    @prediction.scan(/\[([^\]]*)\]/).map(&:first).each do |rephrases|
      rephrase = rephrases.split(';', -1).map(&:strip).sample #TODO should be smarter about 140 chars
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
    "#{@prediction} (#{@prediction.size} chars)"
  end
end

class PunditBot
  def initialize
    process_csv!
    @parties = [Party.new("Democratic Party", ["Dems", "Democrats"], 'D'), Party.new("Republican Party", ["G.O.P.", "Republicans"], 'R')]
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


  def find_years(race, party)
    # find years in which political verb phrase is true wrt party
    if race == :pres

    else
      raise NotYetImplementedError
    end
  end

  def find_data(hash_of_results)
    # for our data sets, find the earliest election year where the data condition matches that year's value in the vector_to_match every year or all but once.
    raise JeremyMessedUpError unless hash_of_results.is_a? Hash
    # like {2012 => true, 2008 => true, 2004 => false} if we're talking about Dems winning WH

    # datasets must all look like this {2004 => 5.5, 2008 => 5.8, 2012 => 8.1 }
    dataset = Hash[*CSV.read('data/correlates/fake_unemployment.csv', {:headers => true}).map{|row| [row["Year"], row["Annual"]] }.flatten]
    dataset_noun = "fake unemployment"
    dataset_min_year = dataset.keys.sort.first

    trues, falses = dataset.to_a.partition.each_with_index{|val, idx| hash_of_results[val[0]] } #TODO: factor out; but something like it is used in predicates
    puts trues.inspect
    # predicates need a lambda and an English template
    predicates = [
      { l: lambda{|x, _|  x > trues.map{|a, b| b}.min }, 
        phrase: "<noun> was greater than #{trues.map{|a, b| b}.min}" }, # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
        # polarity: 
      
      { l: lambda{|x, _| x < trues.map{|a, b| b}.max }, 
        phrase: "<noun> was less than #{trues.map{|a, b| b}.max}" }, # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
        # polarity: 
      { l: lambda{|x, _| x.to_s.chars.last.to_i % 2 == 0 }, 
        phrase: "<noun> ended in an even number",
        # polarity: 
      }, 
      { l: lambda{|x, _| x.to_s.chars.last.to_i % 2 == 1 }, 
        phrase: "<noun> ended in an odd number",
        # polarity: 
      }, 
      { l: lambda{|x, yr| x > dataset[(yr.to_i-1).to_s] }, 
        phrase: "<noun> grew from the previous year",
        # polarity: 
      }, 
      { l: lambda{|x, yr| x < dataset[(yr.to_i-1).to_s] }, 
        phrase: "<noun> declined from the previous year",
        # polarity: 
      }, 
    ]

    result_needs_better_name = nil
    predicates.product(POLARITIES).shuffle.find do |pred, polarity|
      # find the most recent two years where the pattern is broken
      exceptional_year = nil
      start_year = nil
      @election_years.reverse.each_with_index do |yr, idx|
        next if yr < (dataset_min_year.to_i - 1).to_s
        raise JeremyMessedUpError unless idx > 0 || yr != "2014" 
        # find the second year for which the pattern doesn't fit
        if pred[:l].call(dataset[yr], yr) == (hash_of_results[yr] == polarity) # if this year matches the pattern
          # do nothing
        elsif exceptional_year.nil? # if this is the first year that doesn't match the pattern
          exceptional_year = yr
        else #this is the second year that doesn't match the pattern
          start_year = yr
          break
        end
      end
      start_year = dataset_min_year if start_year.nil?
      puts "Start year: #{start_year}"
      if start_year > "1988"
        false
      else
        result_needs_better_name = {
          data_claim: pred[:phrase].gsub('<noun>', dataset_noun),
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
      prediction.data['ending'] = " [except; save] #{data[:exceptional_year]}" #note initial space
      prediction.data['time_phrase_1'] = "has #{data[:polarity] ? '' : 'not'}"
      prediction.data['time_phrase_2'] = "in #{data[:polarity] ? 'every' : 'any'} year"
    else
      prediction.data['ending'] = ''
      prediction.data['time_phrase_1'] = "has #{data[:polarity] ? 'always' : 'never'}"
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
end.compact)

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
