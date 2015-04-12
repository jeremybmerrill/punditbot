require 'csv'
require 'yaml'
require 'simplernlg' if RUBY_PLATFORM == 'java'
puts "Warning, this only works on JRuby" if RUBY_PLATFORM != 'java'

class JeremyMessedUpError < StandardError; end
#TODO: pre-parse templates, phrases into rearrangeable VPs, PPs, (e.g. Without Iowa, GOP hasn't won the White House since 1948 vs. Since 1948, GOP hasn't won the White House.)

datasets = [] # maybe these are rails models?


# TEMPLATES = [
#   "Since <start_year>, the <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> in which <data_claim><ending>[.;]",
#   "Since <start_year>, <time_phrase_2> <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]",
#   "The <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> since <start_year> in which <data_claim><ending>[.;]",
#   "<time_phrase_2> since <start_year> when <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]"
# ]
POLARITIES = [true, false]
TOO_RECENT_TO_CARE_CUTOFF = 1992 #if the claim is false twice after (including) 1992, then skip the correlation
 
POLITICS_VERB_PHRASES = [
  {
      race: :pres, 
      control: false, # if after the election, the chosen party/person controls the object
      change: false,  # if the election caused a change in control of the object
      object: ["White House", "Presidency"] 
  }

                        # },
                          # "hasn't controlled the Senate" => {},
                          # "hasn't controlled the House" => {},
                          # "has kept or won control of Senate/House" => {},
                          # "has won control of the Senate/House." => {},
                          # "has picked up Senate/House seats" => {},
                          # "has lost Senate/House seats" => {},
                          #TODO: "hasn't won <state>'s electoral votes"
                          #TODO: "hasn't won both of <state>'s Senate seats"
                          #TODO: "hasn't won the White House without <state>",
                        ]

class Noun
  attr_reader :word
  def initialize(word, number)
    @word = word
    @number = number
  end

  def number
    plural? ? :plural : :singular
  end

  def plural?
    @number != 1
  end

  def singular?
    @number == 1
  end

  def to_s
    @word
  end
end

class Party
  attr_reader :name, :alt_names, :wikipedia_symbol
  def initialize(name, alt_names, wikipedia_symbol)
    @name = name.first
    @alt_names = ([name] + alt_names).map{|name, num| Noun.new(name, num) }
    @wikipedia_symbol = wikipedia_symbol
  end

  def sample
    @alt_names.sample
  end
end

PARTIES = [
  Party.new(["Democratic Party", 1], [["Dems", 2], ["Democrats", 2]], 'D'), 
  Party.new(["Republican Party", 1], [["G.O.P.", 1], ["Republicans", 2]], 'R')
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
    @noun = Noun.new(column["noun"], column["noun_number"])
    type = column["type"] || "numeric"
    @data = Hash[*@csv.map{|row| [row[@year_column_header], cleaners[type].call(row[column["header"]])] }.flatten]
  end
end

class Prediction
  attr_reader :prediction, :template
  attr_accessor :complements
  # PHRASE_TYPES = [:s, :v, :o, :c, ]
  MODIFIERS = [:add_post_modifier, :add_pre_modifier, :add_front_modifier]

  def initialize()
    @prediction_meta = {
    }
    @complements = []
  end

  def set(key, val=nil)
    @prediction_meta[key] = val
  end

  def templatize!
    # if it's an array, sample it 
    # TODO: be 140 characters aware
    # to do this, realize the sentence with the shortest options and the longest option
    # to find how much extra space we have (and fail if the shortest length is > 140)
    # then shuffle up all the options and settle randomly, subtracting the difference between the chosen option
    # and the shortest option from the margin. Reject and re-sample if the margin would go below 0.
    # perhaps this should use LexicalVariants
    puts @prediction_meta.inspect
    @prediction_meta.each do |k, v|
      @prediction_meta[k] = v.sample if v.respond_to? :sample
    end
    puts @prediction_meta.inspect

    nlg = SimplerNLG::NLG

    #TODO: maybe nlg.phrase should understand nested phrases, render them automatically as complements
    # so that they're specified as :complements => []
    # which then automatically randomizes post/pre/front

    # create main phrase
    # e.g. "the Republicans have won the Presidency"
    main_clause = {
      :s => nlg.factory.create_noun_phrase('the', @prediction_meta[:party].word), 
      :number => @prediction_meta[:party].number,
      #TODO rename to get rid of the word "verb prhase"
      # TODO make politics verb phrases also an object, so I can just call #verb on it, so it responds to sample
      :v => @prediction_meta[:politics_verb_phrase][:change] ? (@prediction_meta[:politics_verb_phrase][:control] ? 'gain' : 'lose') : (@prediction_meta[:politics_verb_phrase][:control] ? 'win' : 'lose' ), 
      :perfect => true,
      :tense => :present,
      :o => nlg.factory.create_noun_phrase('the', @prediction_meta[:politics_verb_phrase][:object].sample) #TODO sample above
    }
    sentence = nlg.phrase(main_clause)

    complement_subject_noun = @prediction_meta[:data_claim].delete(:s) # the data noun, e.g. unemployment
    year_polarity = @prediction_meta[:claim_polarity]
    comp_subj = nlg.factory.create_noun_phrase(complement_subject_noun.word)
    comp_subj.set_feature nlg::Feature::NUMBER, complement_subject_noun.singular? ? nlg::NumberAgreement::SINGULAR : nlg::NumberAgreement::PLURAL
    comp = nlg.phrase({
        :s => comp_subj,
        :v => @prediction_meta[:data_claim].delete(:v),
        :o => @prediction_meta[:data_claim].delete(:o),
        :c => @prediction_meta[:data_claim].delete(:c),
        :tense => @prediction_meta[:data_claim].delete(:tense),
        :perfect => @prediction_meta[:data_claim].delete(:perfect)
    })
    since_pp = nlg.factory.create_preposition_phrase(['since', 'after'].sample, nlg.factory.create_noun_phrase(@prediction_meta[:start_year]))
    if (exceptional_year = @prediction_meta.delete(:exceptional_year))
      pp = nlg.factory.create_preposition_phrase('in', nlg.factory.create_noun_phrase(year_polarity ? 'every' : 'any', 'year'))
      pp.add_post_modifier(comp)
      pp.send(MODIFIERS.sample, since_pp)
      sentence.send(MODIFIERS.sample,  pp)
      sentence.send(MODIFIERS.sample,  nlg.phrase({:p => ['save', 'except'].sample, :d => nil, :n => exceptional_year}))
    else
      sentence.add_pre_modifier(year_polarity ? 'always' : 'never')
      pp = nlg.factory.create_preposition_phrase('when', comp)
      pp.send(MODIFIERS.sample, since_pp)
      sentence.send(MODIFIERS.sample, pp)
    end

    @prediction = nlg.realizer.realise_sentence(sentence) 
  end

  # def resolve_options!
  #   # N.B. a rephrase can be empty if the phrase is optional.

  #   #TODO: figure out how to do rephrases in a way that's smart about 140 chars
  # end

  def to_s
    @prediction || templatize!
  end

  def inspect
    @prediction || templatize!
    "\"#{@prediction} (#{@prediction.size} chars)\""
  end
end

class PunditBot
  def initialize
    process_csv!
    @parties = PARTIES
    @datasets = YAML.load_file('data/correlates.yml')
  end
  def vectorize_politics_verb_phrase(phrase_meta, party)
    state  = phrase_meta[:state] || "USA"
    race   =  phrase_meta[:race] || :pres
    won    =  phrase_meta[:race] || :pres
    change =  phrase_meta[:race] || :pres
    victors = @elections[race][state]
    tf_vector = Hash[*@election_years.map{|year| [year, victors[year].match(/[A-Z]+/).to_s == party.wikipedia_symbol]}.flatten]
    # puts "tf_vector: #{tf_vector}"
    tf_vector 
  end

  def get_a_dataset!
    @dataset = Dataset.new(@datasets.select{|y| y["filename"] }.sample)
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

    # TODO: predicates need to be divied into types:
    #   those those apply to numbers themselves ('the number of atlantic hurricane deaths was an odd number' for noun 'atlantic hurricane deaths')
    #   those that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
    #   those that apply to categorical data ('an AFC team won the World Series')
    predicates = [
      { l: lambda{|x, _|  x > trues.map{|a, b| b}.min }, 
        phrase: {
          :v => 'be',
          :tense => :past,
          :o => "greater than #{trues.map{|a, b| b}.min}" # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
        }
      },
      
      { l: lambda{|x, _| x < trues.map{|a, b| b}.max }, 
        phrase: {
          :v => 'be',
          :tense => :past,
          :o => "less than #{trues.map{|a, b| b}.max}" # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
        }
      },
      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.last.to_i.even? }, 
        phrase: {
          :v => 'end',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "in an even number"
        }
      }, 
      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.last.to_i.odd? }, #TODO: figure out how to get rid of these dupes (odd/even)
        phrase: {
          :v => 'end',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "in an odd number"
        }
      }, 
      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.first.to_i.even? }, 
        phrase: {
          :v => 'start',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "with an even number"
        }
      }, 
      { l: lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.first.to_i.odd? }, 
        phrase: {
          :v => 'start',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "with an odd number"
        }
      }, 
      { l: lambda{|x, _| x.even? }, 
        phrase: {
          :v => 'be',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "an even number"
        }
      }, 
      { l: lambda{|x, _| x.odd? }, 
        phrase: {
          :v => 'be',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "an odd number"
        }
      }, 

      #TODO: figure out how to handle these
      # { l: lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).even? }, 
      #   phrase: "<noun>'s digits add up to an even number",
      # }, 
      # { l: lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).odd? }, 
      #   phrase: "<noun>'s digits add up to an odd number",
      # }, 
      { l: lambda{|x, yr| x > @dataset.data[(yr.to_i-1).to_s] }, 
        phrase: {
          :v => 'grow',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "from the previous year"
        }
      }, 
      { l: lambda{|x, yr| x < @dataset.data[(yr.to_i-1).to_s] }, 
        phrase: {
          :v => 'decline',
          :tense => :past,
          # TODO: this is actually a complement
          :c => "from the previous year"
        }
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
      if start_year > TOO_RECENT_TO_CARE_CUTOFF.to_s
        false
      else
        puts "pred: #{pred.inspect}"
        result_needs_better_name = {
          data_claim: pred[:phrase].clone.merge({s: @dataset.noun}),
          start_year: start_year, #never nil
          exceptional_year: exceptional_year, # maybe nil
          polarity: polarity
        }
        break
      end
    end

    puts "Results: #{result_needs_better_name}" unless result_needs_better_name.nil?
    result_needs_better_name
  end

  def generate_prediction
    prediction = Prediction.new
    prediction.set(:party, party = @parties.sample) # TODO: party is our subj
    politics_verb_phrase = POLITICS_VERB_PHRASES.sample
    party_wins_vector = vectorize_politics_verb_phrase(politics_verb_phrase, party)

    data = find_data(party_wins_vector)
    #TODO choose between when ... always/never
    # and                in every/no ... (nothing)
    # e.g. * in every year fake unemployment ended in an even number, the Republican Party has always won the white house.
    # e.g.   when fake unemployment ended in an even number, the Republican Party has always won the white house.
    return nil if data.nil?
    prediction.set(:data_claim, data[:data_claim])
    prediction.set(:start_year, data[:start_year])
    prediction.set(:exceptional_year, data[:exceptional_year])
    prediction.set(:claim_polarity, data[:polarity])
    prediction.set(:politics_verb_phrase, politics_verb_phrase)

    prediction.templatize!

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

z = 10.times.to_a.map do |i|
  pundit = PunditBot.new
  prediction = pundit.generate_prediction
  prediction.inspect
end.compact.map(&:to_s).uniq
puts z

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
