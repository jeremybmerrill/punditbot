require 'csv'
require 'yaml'

require 'simplernlg' if RUBY_PLATFORM == 'java'
puts "Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE" if RUBY_PLATFORM != 'java'
NLG = SimplerNLG::NLG


module PunditBot
  POLARITIES = [true, false]
  TOO_RECENT_TO_CARE_CUTOFF = 1992 #if the claim is false twice after (including) 1992, then skip the correlation

  class PoliticsCondition
    # was politics_verb_phrase
    attr_reader :race, :jurisdiction, :objects, :change, :control
    def initialize(obj)
      @race = obj[:race]
      raise ArgumentError, "I don't know about the `#{race}' race" unless [:pres].include?(@race)
      @control = obj[:control]
      @change = obj[:change]
      @objects = obj[:objects].respond_to?( :sample) ? obj[:objects] : [obj[:objects]]
      @jurisdiction = obj[:jurisdiction] || "USA"
    end
    def verb
      # TODO: support other verbs, e.g. pick up seats
      @change ? (@control ? 'gain' : 'give up') : (@control ? 'win' : 'lose')
    end
  end

  class Noun
    attr_reader :word
    def initialize(word, number)
      @word = word.is_a?(Noun) ? word.word : word
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
      "Noun: #{@word}"
    end

    def size
      word.size
    end
  end

  #TODO: reorganize code to put settings (like this, data claims, etc.) in one place
  POLITICS_CONDITIONS = [
    PoliticsCondition.new(
        race: :pres, 
        control: false, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("White House", 1), Noun.new("presidency", 1)] 
    ),
    # PoliticsCondition.new(
    #     race: :pres, 
    #     control: true, # if after the election, the chosen party/person controls the object
    #     change: false,  # if the election caused a change in control of the object
    #     objects: [Noun.new("White House", 1), Noun.new("presidency", 1)] 
    # )
    # PoliticsCondition.new(
    #     race: :pres, 
    #     control: false, # if after the election, the chosen party/person controls the object
    #     change: true,  # if the election caused a change in control of the object
    #     objects: [Noun.new("White House", 1), Noun.new("presidency", 1)] 
    # )
    # PoliticsCondition.new(
    #     race: :pres, 
    #     control: true, # if after the election, the chosen party/person controls the object
    #     change: true,  # if the election caused a change in control of the object
    #     objects: [Noun.new("White House", 1), Noun.new("presidency", 1)] 
    # )

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

  class Party
    attr_reader :name, :alt_names, :wikipedia_symbol
    def initialize(name, alt_names, wikipedia_symbol)
      @name = name.first
      @alt_names = ([name] + alt_names).map{|name, num| Noun.new(name, num) }
      @wikipedia_symbol = wikipedia_symbol
    end

    def rephrase
      @name = @alt_names.sample
      self
    end
    def max_by &blk
      @alt_names.max_by(&blk)
    end
    def min_by &blk
      @alt_names.min_by(&blk)
    end
  end
  PARTIES = [
    Party.new(["Democratic Party", 1], [["Dems", 2], ["Democrats", 2]], 'D'), 
    Party.new(["Republican Party", 1], [["G.O.P.", 1], ["Republicans", 2]], 'R')
  ]

  class DataClaim
    attr_reader :condition, :template
    def initialize(condition, template)
      @template = template
      raise ArgumentError, "DataClaim condition is not callable" unless condition.respond_to? :call
      @condition = condition
    end
    def phrase(complement_subject_noun)
      if !@template[:n].nil?
        complement_subject = @template[:n].call(complement_subject_noun)
      else
        complement_subject = NLG.factory.create_noun_phrase(complement_subject_noun.word)
        complement_subject.set_feature NLG::Feature::NUMBER, complement_subject_noun.singular? ? NLG::NumberAgreement::SINGULAR : NLG::NumberAgreement::PLURAL
      end
      NLG.phrase(@template.merge({
          :s => complement_subject,
      }))
    end
  end


  class Dataset
    attr_reader :name, :noun, :min_year, :data, :source, :data_type
    def initialize(obj) 
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
        :integral     => lambda{|n| n.gsub(/[^\d]/, '').to_i },  #removes dots, so only suitable for claims ABOUT numbers, like 'digits add up an even number'
        :numeric     =>  lambda{|n| n.gsub(/[^\d\.]/, '').to_i }, 
        :categorical =>  lambda{|x| x}
      }
    end

    def get_data!
      #randomly give a column's data
      return @data unless @data.nil?
      column = @data_columns.reject{|column| cleaners[(column["type"] || "numeric").to_sym].nil? }.sample
      # TODO: implement multiple noun support (unit should be a sub-object of noun)
      @noun = Noun.new(column["noun"], column["noun_number"])

      @data_type = (column["type"] || "numeric").to_sym
      @units = column["units"] || []
      @data = Hash[*@csv.map{|row| [row[@year_column_header], 
        begin 
          cleaners[@data_type].call(row[column["header"]])
        rescue NoMethodError => e
          puts row.headers.inspect
          puts column["header"]
          raise e
        end
      ] }.flatten]
    end
    def add_units(intro, number)
      @units.map do |unit|
        unit = {"word" => unit} unless unit.respond_to?(:has_key?) && unit.has_key?("word")
=begin
    units: 
      - degrees
      - word: "°"
        direction: "suffix"
        include_space: false
=end
        if unit["direction"] == "prefix"
          intro + " " + (unit["include_space"] == false ? '' : " ") + unit["word"] + number.to_s
        else # suffix
          intro + " " + number.to_s + (unit["include_space"] == false ? '' : " ") + unit["word"]
        end
      end
    end


  end

  class PunditBot
    def initialize
      process_csv!
      @parties = PARTIES
      @datasets = YAML.load_file('data/correlates.yml')
    end
    def vectorize_politics_condition(politics_condition, party)
      victors = @elections[politics_condition.race][politics_condition.jurisdiction]
      tf_vector = Hash[*@election_years.each_with_index.map do |year, index| 
        if politics_condition.change
          [year, (politics_condition.control == (victors[year].match(/[A-Z]+/).to_s == party.wikipedia_symbol)) && 
            ((index != 0) && (victors[year].match(/[A-Z]+/).to_s != victors[@election_years[index-1]].match(/[A-Z]+/).to_s)) ]
        else
          [year, politics_condition.control == (victors[year].match(/[A-Z]+/).to_s == party.wikipedia_symbol)]
        end
      end.flatten]
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


      trues, falses = @dataset.data.to_a.partition.each_with_index{|val, idx| hash_of_results[val[0]] } #TODO: factor out; but something like it is used in data_claims
      # data_claims need a lambda and an English template

      # TODO: data_claims need to be divied into types:
      #   those those apply to numbers themselves ('the number of atlantic hurricane deaths was an odd number' for noun 'atlantic hurricane deaths')
      #   those that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
      #   those that apply to categorical data ('an AFC team won the World Series')
      data_claims = {
        # claims that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
        :numeric => [
          DataClaim.new( lambda{|x, _|  x > trues.map{|a, b| b}.min }, 
            phrase: {
              :v => 'be',
              :tense => :past,
              :o => @dataset.add_units("greater than", trues.map{|a, b| b}.min) # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
                    

            }
          ),
          
          DataClaim.new( lambda{|x, _| x < trues.map{|a, b| b}.max }, 
            {
              :v => 'be',
              :tense => :past,
              :o => @dataset.add_units("less than", trues.map{|a, b| b}.max) # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
            }
          ),

          DataClaim.new( lambda{|x, yr| x > @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'grow',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous year"
            }
          ), 
          DataClaim.new( lambda{|x, yr| x < @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'decline',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous year"
            }
          ), 
          DataClaim.new( lambda{|x, yr| x > @dataset.data[(yr.to_i-4).to_s] }, 
            {
              :v => 'grow',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous election year"
            }
          ), 
          DataClaim.new( lambda{|x, yr| x < @dataset.data[(yr.to_i-4).to_s] }, 
            {
              :v => 'decline',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous election year"
            }
          ), 
        ],

      # for categorial data
      # TODO: write this.
      # but what does it look like?
      # when the AFC won the Super Bowl?
      # when an NFC team was the Super Bowl winner
      :categorical => [
          DataClaim.new( lambda{|x, yr| }, 
            {
              :v => 'be',
              :tense => :past,
              :o => "asfd asdf TK"
              # TODO: this is actually a complement
            }
          ), 
      ],

      # "integral" data claims are about the numbers qua numbers, e.g. odd, even. 
      :integral => [
          DataClaim.new( lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).even? }, 
            # "<noun>'s digits add up to an even number",
            { 
              :n => lambda do |n| 
                              np = NLG.factory.create_noun_phrase('digit') 
                              np.set_feature NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL
                              possessive = NLG.factory.create_noun_phrase(n.word) 
                              possessive.set_feature NLG::Feature::NUMBER, n.singular? ? NLG::NumberAgreement::SINGULAR : NLG::NumberAgreement::PLURAL
                              possessive.set_feature NLG::Feature::POSSESSIVE, true
                              np.set_specifier(possessive)
                              np
                           end,
              :v => 'add up',
              :tense => :present,
              :c => 'to an even number'
            }
          ), 
          DataClaim.new( lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).odd? }, 
            # "<noun>'s digits add up to an odd number",
            { 
              :n => lambda do |n| 
                              np = NLG.factory.create_noun_phrase('digit') 
                              np.set_feature NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL
                              possessive = NLG.factory.create_noun_phrase(n.word) 
                              possessive.set_feature NLG::Feature::NUMBER, n.singular? ? NLG::NumberAgreement::SINGULAR : NLG::NumberAgreement::PLURAL
                              possessive.set_feature NLG::Feature::POSSESSIVE, true
                              np.set_specifier(possessive)
                              np
                           end,
              :v => 'add up',
              :tense => :present,
              :c => 'to an odd number'
            }
          ), 
          DataClaim.new( lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.last.to_i.even? }, 
            {
              :v => 'end',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "in an even number"
            }
          ), 
          DataClaim.new( lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.last.to_i.odd? }, #TODO: figure out how to get rid of these dupes (odd/even)
            {
              :v => 'end',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "in an odd number"
            }
          ), 
          DataClaim.new( lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.first.to_i.even? }, 
            {
              :v => 'start',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "with an even number"
            }
          ), 
          DataClaim.new( lambda{|x, _| x/10 > 0 && x.to_s.chars.to_a.first.to_i.odd? }, 
            {
              :v => 'start',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "with an odd number"
            }
          ), 
          DataClaim.new( lambda{|x, _| x.even? }, 
            {
              :v => 'be',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "an even number"
            }
          ), 
          DataClaim.new( lambda{|x, _| x.odd? }, 
            {
              :v => 'be',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "an odd number"
            }
          ), 

        ],
      }

      result_needs_better_name = nil
      data_claims[@dataset.data_type || "numeric"].product(POLARITIES).shuffle.find do |data_claim, polarity|
        # find the most recent two years where the pattern is broken
        exceptional_year = nil
        start_year = nil
        @election_years.reverse.each_with_index do |yr, idx|
          next if yr < (@dataset.min_year.to_i - 1).to_s
          raise JeremyMessedUpError unless idx > 0 || yr != "2014" 
          # find the second year for which the pattern doesn't fit
          if data_claim.condition.call(@dataset.data[yr], yr) == (hash_of_results[yr] == polarity) # if this year matches the pattern
            # do nothing
            # puts "match: #{yr},  #{data_claim.condition.call(@dataset.data[yr], yr)}, #{@dataset.data[yr]}"
          elsif exceptional_year.nil? # if this is the first year that doesn't match the pattern
            exceptional_year = yr
            # puts "exceptional_year: #{yr},  #{data_claim.condition.call(@dataset.data[yr], yr)}, #{@dataset.data[yr]}"
          else #this is the second year that doesn't match the pattern
            start_year = (yr.to_i + 4).to_s 
            break
          end
        end
        start_year = @dataset.min_year if start_year.nil?
        # TODO: uncomment and test this! it's meant to be a guard against saying
        # since 1996, except 2000, X has occured,
        # if exceptional_year.to_i - start_year.to_i == 4
        #   start_year = exceptional_year
        #   exceptional_year = nil
        # end
        if start_year > TOO_RECENT_TO_CARE_CUTOFF.to_s
          false
        else
          result_needs_better_name = {
            data_claim: data_claim,
            correlate_noun: @dataset.noun,
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
      politics_condition = POLITICS_CONDITIONS.sample
      politics_claim_truth_vector = vectorize_politics_condition(politics_condition, party)

      data = find_data(politics_claim_truth_vector)
      return nil if data.nil?
      prediction.set(:data_claim, data[:data_claim])
      prediction.set(:correlate_noun, data[:correlate_noun])
      prediction.set(:start_year, data[:start_year])
      prediction.set(:exceptional_year, data[:exceptional_year])
      prediction.set(:claim_polarity, data[:polarity])
      prediction.set(:politics_condition, politics_condition)

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
      @elections = {:pres => {}}
      csv.each{|row| @elections[:pres][row["State"]] = row.to_hash }
      @elections[:pres][usa_winner["State"]] = usa_winner
    end
  end


end