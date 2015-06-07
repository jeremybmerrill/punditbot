require 'simplernlg' if RUBY_PLATFORM == 'java'
puts "Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE" if RUBY_PLATFORM != 'java'
NLG = SimplerNLG::NLG

module PunditBot


class Prediction
  attr_reader :prediction
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

  def _realize_sentence(rephraseables)
        #TODO: maybe nlg.phrase should understand nested phrases, render them automatically as complements
    # so that they're specified as :complements => []
    # which then automatically randomizes post/pre/front

    # create main phrase
    # e.g. "the Republicans have won the Presidency"
    party_word = rephraseables[:party].first
    subj = NLG.factory.create_noun_phrase('the', party_word.word)
    claim_polarity = @prediction_meta[:claim_polarity]
    main_clause = {
      :s => subj,
      :number => party_word.number,
      :v => @prediction_meta[:politics_condition].verb, 
      :perfect => true,
      :tense => :present,
      :o => NLG.factory.create_noun_phrase('the', rephraseables[:politics_condition_object].first.word),
      :negation => !claim_polarity
    }
    sentence = NLG.phrase(main_clause)

    data_phrase = @prediction_meta[:data_claim].phrase(@prediction_meta[:correlate_noun]) #TODO correlate_noun should be rephraseable
    data_phrase.set_feature(NLG::Feature::SUPRESSED_COMPLEMENTISER, true)
    since_pp = NLG.factory.create_preposition_phrase(rephraseables[:since_after].first, NLG.factory.create_noun_phrase(@prediction_meta[:start_year]))
    #TODO choose between when ... always/never
    # and                in every/no ... (nothing)
    # e.g. * in every year fake unemployment ended in an even number, the Republican Party has always won the white house.
    # e.g.   when fake unemployment ended in an even number, the Republican Party has always won the white house.
    if (exceptional_year = @prediction_meta[:exceptional_year])

      prep_phrase = NLG.factory.create_preposition_phrase('in', NLG.factory.create_noun_phrase(claim_polarity ? 'every' : 'any', rephraseables[:year_election].first ))
      with MODIFIERS.sample do |modifier_position|
        if modifier_position == :add_front_modifier
          sentence.send(modifier_position, since_pp)
        else
          since_pp.set_feature(NLG::Feature::APPOSITIVE, true)
          [sentence, prep_phrase].sample.send(modifier_position, since_pp)
        end
      end
      except_phrase = NLG.factory.create_preposition_phrase(rephraseables[:except].first, NLG.factory.create_noun_phrase(exceptional_year) )
      with  [[sentence,(MODIFIERS - [:add_pre_modifier] ).sample], [prep_phrase, :add_post_modifier]].sample do |modified, method|
       modified.send(method, except_phrase)#TODO: get pre_modifiers working with commas
     end
      prep_phrase.add_post_modifier(data_phrase)

      sentence.send((MODIFIERS - [:add_pre_modifier] ).sample,  prep_phrase) #TODO: get pre_modifiers working with commas (right now it's "SUBJ has, PREPOSITION whatever VERBed OBJ", lacking the second comma)
    else
      sentence.add_pre_modifier(claim_polarity ? 'always' : 'never')
      sentence.set_feature(NLG::Feature::NEGATED, false) if !claim_polarity
      prep_phrase = NLG.factory.create_preposition_phrase(rephraseables[:when].first, data_phrase)
      prep_phrase.send( (MODIFIERS - [:add_front_modifier]).sample, since_pp) # TODO why does :add_front_modifier not work here?
      sentence.send((MODIFIERS - [:add_pre_modifier] ).sample, prep_phrase) #TODO: get pre_modifiers working with commas (right now it's "SUBJ has, PREPOSITION whatever VERBed OBJ", lacking the second comma)
    end
    NLG.realizer.setCommaSepCuephrase(true) # for "front modifier" sentences, puts a comma after the modifier.
    NLG.realizer.setCommaSepPremodifiers(true) # for pre-modifier sentences
    # puts sentence
    NLG.realizer.realise_sentence(sentence) 
  end

  def templatize!

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

    rephraseables = {}
    rephraseables[:politics_condition_object] = @prediction_meta[:politics_condition].objects.dup
    rephraseables[:party] = @prediction_meta[:party].alt_names.dup
    rephraseables[:since_after] = ['since', 'after']
    rephraseables[:except] = ['except', 'besides'] 
    rephraseables[:when] = ['when', 'in years when', 'whenever', 'in every year']
    rephraseables[:year_election] = ["year", "election year"]
    # collect all the rephraseable elements

    min_rephraseable_length = 0
    max_rephraseable_length = 0
    unrephraseable_length = 0 
    rephraseables.each do |k, v|
      if v.respond_to? :rephrase
        max_rephraseable_length += v.max_by(&:size).size # +1 for spaces
        min_rephraseable_length += v.min_by(&:size).size # +1 for spaces
      end
    end

    # render sentence!
    shortest_rephrase_options = {}
    rephraseables.each do |k, v|
      shortest_rephrase_options[k] = [v.min_by(&:size)]
    end
    shortest_possible_sentence_length = _realize_sentence(shortest_rephrase_options).size
    return nil if MAX_OUTPUT_LENGTH < shortest_possible_sentence_length
    buffer = MAX_OUTPUT_LENGTH - shortest_possible_sentence_length # [max_rephraseable_length - min_rephraseable_length, MAX_OUTPUT_LENGTH - shortest_possible_sentence_length].min
    # puts "Buffer: #{buffer}"

    rephraseables.to_a.shuffle.each do |k, v|

      weighted = v.reduce([]){|memo, nxt| memo += [nxt] * nxt.size }
      weighted.shuffle!
      #TODO: rather than choosing randomly, should prefer longer versions
      chosen_word = weighted.first
      # puts "Buffer: #{buffer.to_s.size == 1 ? ' ' : ''}#{buffer}, chose '#{chosen_word}' from #{v}"
      redo if buffer - (chosen_word.size - weighted.min_by(&:size).size) < 0 # I think this is bad. I think this'll never end.
      rephraseables[k] = [chosen_word]
      buffer -= (chosen_word.size - weighted.min_by(&:size).size)
    end

    @prediction = _realize_sentence(rephraseables)
  end

  def to_s
    @prediction || templatize!
  end

  def inspect
    @prediction || templatize!
    @prediction.nil? ? nil : "#{@prediction.size} chars: \"#{@prediction}\""
  end
end

end