require 'simplernlg' if RUBY_PLATFORM == 'java'
puts "Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE" if RUBY_PLATFORM != 'java'

class Hash
  def self.recursive
    new { |hash, key| hash[key] = recursive }
  end
end
def dupnil(obj)
  obj.nil? ? nil : obj.dup
end

module PunditBot


# TODO, "except in YR", attached to the main phrase should be acceptable
# TODO: rename @sentence_diagram and @final_sentence_diagram
# too many commas here: "Since 1992, a Republican has not won the the presidency, in any year that the price of a ton of iron ore declined year over year."


class Prediction
  attr_accessor :prediction_meta, :prediction_debug
  # MODIFIERS = [:add_post_modifier, :add_pre_modifier, :add_front_modifier]
  MAX_OUTPUT_LENGTH ||= 140

  def initialize

    @final_sentence_diagram = {}
    @prediction_meta  = {}

    # this should only be used for debugging, e.g. prove_it!
    @prediction_debug = {}
  end

  def self.realize_sentence(sentence_diagram)
    SimplerNLG::NLG.render(sentence_diagram)
  end

  def actually_make_the_sentence
    rephrased = rephrase(rephraseables.dup) # `dup` b/c we need to be able to remove things from this list without it causing a problem later.
    @prediction_text = _realize_sentence(rephrased)
    @prediction_text
  end

  # TODO:
  def magically_get_number_from(obj)
    1
  end

  def rephraseables
    rephrased = {}
    rephrased[:party_noun] =               dupnil(@prediction_meta[:party].alt_names)            # the democrats
    rephrased[:politics_condition_verb]  = dupnil(@prediction_meta[:politics_condition].verb)    # lost
    rephrased[:politics_condition_object]= dupnil(@prediction_meta[:politics_condition].objects) # the white house
    rephrased[:data_claim_obj] =           (@prediction_meta[:data_claim_template][:o].respond_to?(:min_by) ? @prediction_meta[:data_claim_template][:o] : [@prediction_meta[:data_claim_template][:o]]) if @prediction_meta[:data_claim_template].has_key?(:o) && @prediction_meta[:data_claim_template][:o]                                              # greater
    rephrased[:correlate_noun] =           dupnil(@prediction_meta[:correlate_noun])             # unemployment
    puts "correlate noun: #{dupnil(@prediction_meta[:correlate_noun])   }"
    rephrased[:since_pp_position] =        [:pre, :post, :front]
    rephrased[:every_year_pp_position] =   [:pre, :post, :front]
    rephrased[:since_after] =              ['since', 'after', 'starting in']
    rephrased[:except] =                   ['except', 'besides', 'except in'] 
    rephrased[:year_or_election] =         ["year", "election year"]
    rephrased[:when] =                     ['when', 'in years when', 'whenever', 'in years']
    rephrased[:since_pp_modified] =        [:main_clause, :year_pp]
    rephrased
  end

  def _realize_sentence(rephrased)
    # should pull only from @prediction_meta and rephrased
    # I don't think we ever will need to vary anything from @prediction_meta
    puts "s: #{@prediction_meta[:data_claim_template][:n].nil? ? rephrased[:correlate_noun] : @prediction_meta[:data_claim_template][:n].call(rephrased[:correlate_noun])}"
    sentence_template = {
      :s => rephrased[:party_noun].word,
      :number => rephrased[:party_noun].number, # 1 or 2, depending on grammatical number of rephrased[:party_noun]
      :v => rephrased[:politics_condition_verb], 
      :perfect => true,
      :tense => :present,
      :o => { :det => 'the', 
              :noun => rephrased[:politics_condition_object].word
      },
      :negation => !@prediction_meta[:claim_polarity],
      :prepositional_phrases => [ # these should be randomly assigned as modifiers
        {
          :preposition => "in",
          :rest => {
                    :determiner => @prediction_meta[:claim_polarity] ? 'every' : 'any',
                    :noun =>       rephrased[:year_or_election],
                    :complements => [{
                        :complementizer => rephrased[:when], # NLG::Feature::COMPLEMENTISER, 'when' # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG
                    }.
                    merge(@prediction_meta[:data_claim_template]).
                    merge(:s => @prediction_meta[:data_claim_template][:n].nil? ? rephrased[:correlate_noun].word : @prediction_meta[:data_claim_template][:n].call(rephrased[:correlate_noun]) )],
                  },
          :appositive => true,
          :position => rephrased[:every_year_pp_position]
        }
      ]
    }
    since_pp = {
          # TODO: this should optionally also be allowed to attach to the "in every year" PP that's right below.
          :preposition => rephrased[:since_after],
          :rest => @prediction_meta[:start_year],
          :appositive => true, # maybe this should just check for whether it's a word or more than one word
          :position => rephrased[:since_pp_position]
        }
    if rephrased[:since_pp_modified ] == :main_clause || rephrased[:since_pp_position] == :front # for now, we can't allow this to be a frontmodifier if it's modifying the year_pp
      puts "since_pp_modified is main_clause"
      sentence_template[:prepositional_phrases] << since_pp
    elsif rephrased[:since_pp_modified ] == :year_pp
      puts "since_pp_modified is year_pp" # tROUBLE
      sentence_template[:prepositional_phrases].find{|pp| pp[:rest][:noun] == rephrased[:year_or_election]}[:prepositional_phrases] = [since_pp]
    else
      raise ArgumentError, "couldn't figure out where to put the since_pp"
    end


    if @prediction_meta[:exceptional_year]
      sentence_template[:prepositional_phrases] <<  {
                                                      :preposition => rephrased[:except],
                                                      :rest => @prediction_meta[:exceptional_year],
                                                      :appositive => true,
                                                      :position => :post
                                                    }
    end
    puts sentence_template.inspect
    Prediction.realize_sentence(sentence_template)
  end


  def rephrase(rephraseables)

    # this is mostly 140-char awareness
    # to do this, we realize the sentence with the shortest option for each "rephraseable" piece of the sentence
    # to find how much extra space we have (and fail if the shortest possible length is > 140).
    # the "margin" -- the extra characters we have to distribute between rephrase options
    #  -- is the difference between the sum of the shortest and sum of the longest rephraseables
    # or the difference between the length of the shortest possible sentence and 140, whichever is less.
    # then, for each rephraseable, we shuffle up all the options and pick one randomly, 
    # subtracting the difference between the chosen option and the shortest option from the margin. 
    # Reject and re-sample if the margin would go below 0.
    # rephraseable objects like Party are also handled here.
    # which perhaps should implement a Rephraseable mix-in so they can have min_by, max_by

    rephraseables.compact!
    rephraseables.reject!{|k, v| v.empty? }
    rephrased = {}
    shortest_rephrase_options = {}

    rephraseables.each do |k, v|
      rephrased[k] = shortest_rephrase_options[k] = rephraseables.delete(k) unless v.respond_to?(:min_by)
    end

    min_rephraseable_length = 0
    max_rephraseable_length = 0
    unrephraseable_length = 0 
    rephraseables.each do |k, v|
      if v.respond_to?(:min_by) && v.size > 0
        max_rephraseable_length += v.max_by(&:size).size # +1 for spaces
        min_rephraseable_length += v.min_by(&:size).size # +1 for spaces
      end
    end

    # render sentence!
    rephraseables.each do |k, v|
      shortest_rephrase_options[k] = v.min_by(&:size)
    end
    puts shortest_rephrase_options.inspect
    shortest_possible_sentence_length = _realize_sentence(shortest_rephrase_options).size
    puts "way too long: #{_realize_sentence(shortest_rephrase_options)}" if MAX_OUTPUT_LENGTH < shortest_possible_sentence_length
    return nil if MAX_OUTPUT_LENGTH < shortest_possible_sentence_length
    buffer = MAX_OUTPUT_LENGTH - shortest_possible_sentence_length # [max_rephraseable_length - min_rephraseable_length, MAX_OUTPUT_LENGTH - shortest_possible_sentence_length].min
    # puts "Buffer: #{buffer}"

    rephraseables.to_a.shuffle.each do |k, v|
      # rather than choosing randomly, should prefer longer versions
      # we put each option into the hat once per character in it
      weighted = v.reduce([]){|memo, nxt| memo += [nxt] * nxt.size }
      weighted.shuffle!
      chosen_word = weighted.first
      # puts "Buffer: #{buffer.to_s.size == 1 ? ' ' : ''}#{buffer}, chose '#{chosen_word}' from #{v}"
      redo if buffer - (chosen_word.size - weighted.min_by(&:size).size) < 0 # I think this is bad. I think this'll never end.
      rephrased[k] = chosen_word
      puts "chosen word: #{chosen_word}"
      buffer -= (chosen_word.size - weighted.min_by(&:size).size)
    end
    puts rephrased.inspect
    rephrased
  end




  def to_s
    @prediction_text || actually_make_the_sentence
  end

  # def old_exhortation
  #   @data_phrase
  #   party_member_name, claim_polarity = *[[@prediction_meta[:party].member_name, @prediction_meta[:claim_polarity]], [@prediction_meta[:party].member_name.downcase.include?("democrat") ? "Republican" : "Democrat", !@prediction_meta[:claim_polarity]]].sample 
  #   @data_phrase.set_feature(NLG::Feature::TENSE, NLG::Tense::PRESENT)
  #   # @data_phrase.set_feature(NLG::Feature::SUPRESSED_COMPLEMENTISER, true)
  #   @data_phrase.set_feature(NLG::Feature::COMPLEMENTISER, 'that') # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG
  #   @data_phrase.set_feature(NLG::Feature::NEGATED,  @prediction_meta[:politics_condition].control ? !claim_polarity : claim_polarity)

  #   pp = NLG.factory.create_preposition_phrase(NLG.factory.create_noun_phrase('this', 'year'))
  #   # What I can generate:
  #   #   Democrats should hope that bears killed more than 10 people this year.
  #   #   This year, Democrats, you need to hope that bears killed more than 10 people.
  #   #   If you're a Democrat, this year, you should hope that bears killed more than 10 people.
  #   #   Democrats, hope that bears killed more than 10 people this year.
  #   # What I'd like to generate:
  #   #   Democrats should hope for more snow this year...
  #   #   Democrats should hope Central Park snow increases year over year.
  #   #   If you're a Democrat, you should hope _________
  #   #   If you're a Democrat, you want vegetable use to increase this year.
  #   #   Republicans, you need to hope that DDDDDDD is an even number this year.

  #   case [:you, :if, :imperative].sample # removed :bare because it sucks
  #   when :bare
  #     np = NLG.factory.create_noun_phrase(party_member_name)
  #     np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
  #     phrase = NLG.phrase({
  #       :s => np,
  #       :number => :plural,
  #       :v => 'hope',
  #       :modal => "should",
  #       :tense => :present,
  #     })
  #     phrase.add_complement(@data_phrase)
  #     modifiers = [:add_post_modifier, :add_front_modifier]
  #     phrase.send(modifiers.sample,  pp)

  #     NLG.realizer.setCommaSepCuephrase(true)
  #   when :you
  #     phrase = NLG.phrase({
  #       :s => "you",
  #       :number => :plural,
  #       :v => 'need',
  #       :tense => :present,
  #     })

  #     inner = NLG.phrase({
  #       :v => "hope"
  #     })

  #     inner.add_complement(@data_phrase)

  #     party_np = NLG.factory.create_noun_phrase(party_member_name)
  #     party_np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
  #     phrase.add_front_modifier(party_np) # cue phrase

  #     modifiers = [:add_post_modifier, :add_front_modifier]
  #     phrase.send(modifiers.sample,  pp)
  #     inner.set_feature(NLG::Feature::FORM, NLG::Form::INFINITIVE)
  #     phrase.add_complement(inner)
  #     NLG.realizer.setCommaSepCuephrase(true)
  #   when :if
  #     phrase = NLG.phrase({
  #       :s => "you",
  #       :number => :plural,
  #       :v => 'hope',
  #       :modal => "should",
  #       :tense => :present,
  #     })
  #     phrase.add_complement(@data_phrase)
  #     phrase.add_front_modifier("if you're a " + party_member_name)
  #     modifiers = [:add_post_modifier, :add_front_modifier]
  #     phrase.send(modifiers.sample,  pp)

  #     NLG.realizer.setCommaSepCuephrase(true)
  #   when :imperative
  #     phrase = NLG.phrase({
  #       :number => :plural,
  #       :v => ['hope', 'pray'].sample,
  #       :tense => :present,
  #     })
  #     phrase.add_complement(@data_phrase)
  #     modifiers = [:add_post_modifier, :add_front_modifier]
  #     phrase.send(modifiers.sample,  pp)
  #     phrase.set_feature(NLG::Feature::FORM, NLG::Form::IMPERATIVE)
  #     np = NLG.factory.create_noun_phrase(party_member_name)
  #     np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
  #     phrase.add_front_modifier( np ) # cue phrase
  #     NLG.realizer.setCommaSepCuephrase(true)
  #   end

  #   @exhortation =       NLG.realizer.realise_sentence(phrase).gsub("the previous", "last")
  #    # Democrats, you need to hope carrot use grows from last year this year.
     
  #   @exhortation.gsub!(" does not ", " doesn't ") if [true, false].sample

  #   @exhortation
  # end

  # important debugging stuff 

  def prove_it!
    """ e.g.
      2012  2008  2004  2000  1996  1992  1988
      7.8   8.2   7.9   8.1   etc   etc   etc 
      true  true  false false true  true  false
    """
    years = @prediction_debug[:covered_years]
    data = years.map{|yr| @prediction_debug[:data][yr] }
    max_data_length = [data.map{|d| d.to_s.size }.max, 4].max #max length in chars of each of the numbers from the dataset
    data_truth = data.zip(years).map do |datum, yr| 
      begin
        @prediction_debug[:data_claim].condition.call(datum, yr)
      rescue ArgumentError
        nil
      end
    end
    victor = years.map{|yr| @prediction_debug[:politics_claim_truth_vector][yr] }
    
    pad = lambda{|x| (x.to_s + "    ")[0...max_data_length]}

    [years, data, data_truth, victor].map{|row| row.map(&pad).join("\t")}.join("\n")
  end

  def column
    # hurricanes, unemployment, veggies,etc.
    @prediction_meta[:correlate_noun].first.word
  end

  def dataset
    # e.g. integral, whatever
    @prediction_meta[:dataset]
  end

  def column_type
    # e.g. integral, whatever
    @prediction_meta[:data_claim_type]
  end

  def metadata
    {
      column_type: column_type,
      data_claim: @prediction_meta[:data_claim_template].values.map(&:to_s).sort.join(" ")
    }
  end


  def inspect
    @prediction_text
    # [#{dataset}, #{column}, #{column_type}]
    @prediction_text.nil? ? nil : "#{@prediction_text.size} chars: \"#{@prediction_text}\"\n#{self.prove_it!}\n"
  end
end # ends the class

end # ends the module


if __FILE__ == $0
  Prediction.new(MOCKUP, nil)
end
