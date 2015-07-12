require 'simplernlg' if RUBY_PLATFORM == 'java'
puts "Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE" if RUBY_PLATFORM != 'java'

module PunditBot


class Prediction
  attr_reader :prediction
  attr_accessor :complements
  # PHRASE_TYPES = [:s, :v, :o, :c, ]
  MODIFIERS = [:add_post_modifier, :add_pre_modifier, :add_front_modifier]

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
      :o => NLG.factory.create_noun_phrase(rephraseables[:politics_condition_object].first.word),
      :negation => !claim_polarity
    }
    sentence = NLG.phrase(main_clause)

    @prediction_meta[:data_claim].template[:o] = (rephraseables[:prediction_meta_data_claim_o].nil?) ? nil : rephraseables[:prediction_meta_data_claim_o].first 
    data_phrase = @prediction_meta[:data_claim].phrase(rephraseables[:correlate_nouns].first) #TODO correlate_noun should be rephraseable

    since_pp = NLG.factory.create_preposition_phrase(rephraseables[:since_after].first, NLG.factory.create_noun_phrase(@prediction_meta[:start_year]))
    if (exceptional_year = @prediction_meta[:exceptional_year])
      year_noun_phrase = NLG.factory.create_noun_phrase(claim_polarity ? 'every' : 'any', rephraseables[:year_election].first)
      data_phrase.set_feature(NLG::Feature::COMPLEMENTISER, 'when') # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG
      year_noun_phrase.add_complement(data_phrase) # was add_post_modifier
      prep_phrase = NLG.factory.create_preposition_phrase('in', year_noun_phrase)

      with MODIFIERS.sample do |modifier_position|
        case modifier_position 
        when :add_front_modifier
          since_pp.set_feature(NLG::Feature::APPOSITIVE, true)
          modified = sentence
          # sentence.subject = (modified == sentence ? "sentence" : "prep_phrase") + " front"  # for testing
        when :add_pre_modifier
          since_pp.set_feature(NLG::Feature::APPOSITIVE, true)
          modified = [sentence, prep_phrase].sample
          # sentence.subject = (modified == sentence ? "sentence" : "prep_phrase") + " pre" # for testing
        when :add_post_modifier
          since_pp.set_feature(NLG::Feature::APPOSITIVE, true)
          modified = [sentence, prep_phrase].sample
          # sentence.subject = (modified == sentence ? "sentence" : "prep_phrase") + " post" # for testing
        end
        modified.send(modifier_position, since_pp)
        
      end
      except_phrase = NLG.factory.create_preposition_phrase(rephraseables[:except].first, NLG.factory.create_noun_phrase(exceptional_year) )
      with  [ [prep_phrase, :add_post_modifier]].sample do |modified, method| # used to include [sentence,(MODIFIERS - [:add_pre_modifier] ).sample],
        except_phrase.set_feature(NLG::Feature::APPOSITIVE, true)
        modified.send(method, except_phrase)#TODO: get pre_modifiers working with commas
      end

      sentence.send((MODIFIERS - [:add_pre_modifier] ).sample,  prep_phrase) #TODO: get pre_modifiers working with commas (right now it's "SUBJ has, PREPOSITION whatever VERBed OBJ", lacking the second comma)
    else
      sentence.add_pre_modifier(claim_polarity ? 'always' : 'never')
      sentence.set_feature(NLG::Feature::NEGATED, false) if !claim_polarity
      data_phrase.set_feature(NLG::Feature::SUPRESSED_COMPLEMENTISER, true) # note to self: what does this do??
      prep_phrase = NLG.factory.create_preposition_phrase(rephraseables[:when].first, data_phrase)
      since_pp.set_feature(NLG::Feature::APPOSITIVE, true)
      prep_phrase.send( (MODIFIERS - [:add_front_modifier]).sample, since_pp) # TODO why does :add_front_modifier not work here?
      prep_phrase.set_feature(NLG::Feature::APPOSITIVE, true)
      sentence.send((MODIFIERS - [:add_pre_modifier] ).sample, prep_phrase) #TODO: get pre_modifiers working with commas (right now it's "SUBJ has, PREPOSITION whatever VERBed OBJ", lacking the second comma)
    end
    NLG.realizer.setCommaSepCuephrase(true) # for "front modifier" sentences, puts a comma after the modifier.
    NLG.realizer.setCommaSepPremodifiers(true) # for pre-modifier sentences
    # puts sentence
    NLG.realizer.realise_sentence(sentence).gsub(/,,+/, ',')
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
    rephraseables[:since_after] = ['since', 'after', 'starting in']
    rephraseables[:except] = ['except', 'besides'] 
    rephraseables[:when] = ['when', 'in years when', 'whenever', 'in years']
    rephraseables[:year_election] = ["year", "election year"]
    rephraseables[:correlate_nouns] = @prediction_meta[:correlate_noun]
    rephraseables[:prediction_meta_data_claim_o] = @prediction_meta[:data_claim].template[:o] if @prediction_meta[:data_claim].template.has_key?(:o)
    # collect all the rephraseable elements
    # rephraseables[:data_claim_object] = [] if [].respond_to?(:rephrase)
    rephraseables.compact!
    rephraseables.reject!{|k, v| v.empty? }

    min_rephraseable_length = 0
    max_rephraseable_length = 0
    unrephraseable_length = 0 
    rephraseables.each do |k, v|
      if v.respond_to?(:rephrase) && v.size > 0
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
      rephraseables[k] = [chosen_word]
      buffer -= (chosen_word.size - weighted.min_by(&:size).size)
    end

    @prediction_text = _realize_sentence(rephraseables)
  end

  def to_s
    @prediction_text || templatize!
  end

  def inspect
    @prediction_text || templatize!
    # [#{dataset}, #{column}, #{column_type}]
    @prediction_text.nil? ? nil : "#{@prediction_text.size} chars: \"#{@prediction_text}\""
  end
end # ends the class

end # ends the module
