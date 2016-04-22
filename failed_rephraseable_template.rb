
  # ###How to make the input structure for realize_sentence.rb (i.e. the output of generate_prediction_data.rb) more like a sentence diagram:
  # Input is the same as the input of SimplerNLG, except EVERY value is a list of acceptable values. Rephraseable sits in between realize_sentence.rb and SimplerNLG and does its thing taking one member from the list. This'll leave lots of one-length lists, but that's okay.
  # But then how do I deal with values that set two keys? (Like :subject and :number)?
  # And how do I deal with values where the rephraseable is embedded? (By breaking it up)


  def pick_rephrase_choices
    # maybe what this should actually do is take the first for all choices
    # but sequentially iterate through each one to find the min and max for that choice.
    # to account for the fact that the "longer" option may not lead to the sentence being longer
    # e.g. :perfect => false is *shorter* than :perfect => true
    # maybe I only need to do that for non-string choices.

    # older comment: 
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


    @rephraseable_keys = []
    @rephraseables = Hash.recursive
    level = 0
    # find everything rephraseable in the sentence_diagram
    # so we get a flat list
    # or recursively loop throughj??

    # we want to find every Array in @sentence_diagram
    # and put it in rephraseables (keeping track of where it belongs)
    @sentence_diagram.each{|k, v| gather_rephraseables(v, [k]) }

    # hold on a sec, do we even DO anything with this??
    # # we find the amount of variation in length that we have
    # # by finding the shortest and longest option for each rephraseable 
    # min_rephraseable_length = 0
    # max_rephraseable_length = 0
    # unrephraseable_length = 0 
    # rephraseables.each do |k, v|
    #   if v.all?{|member| member.respond_to?(:size)}
    #     min_rephraseable_length += v.min_by(&:size).size
    #     max_rephraseable_length += v.max_by(&:size).size
    #   else
    #     # TODO
    #     # it's a boolean or something where we actually have to create the sentence to find the differences in length.
    #     lengths = v.map do |option|
    #       # deep-copy @sentence_diagram;    d = Marshal.load( Marshal.dump(h) )
    #       # make a choice for each option except k
    #       # then set k to option and compute the difference in length for each
    #       # self.realize_sentence()
    #     end
    #     max_rephraseable_length += lengths.max - lengths.min
    #   end
    # end


    shortest_rephrase_options = {}
    rephraseables.each do |k, v|
      if v.all?{|i| i.respond_to?(:size)} # if the Rephraseable is a list of words, not a list of options or settings
        shortest_rephrase_options[k] = [v.min_by(&:size)]
      else
        # TODO
      end
    end
    # we need a method to duplicate all the single members of @sentence_diagram
    # and then _realize_sentence should, given a certain list of rephraseables choices, nondestructively render the sentence

    shortest_possible_sentence_length = _realize_sentence(shortest_rephrase_options).size
    if MAX_OUTPUT_LENGTH < shortest_possible_sentence_length
      puts "way too long: #{_realize_sentence(shortest_rephrase_options)}" 
      return nil
    end
    buffer = MAX_OUTPUT_LENGTH - shortest_possible_sentence_length 
    # [max_rephraseable_length - min_rephraseable_length, MAX_OUTPUT_LENGTH - shortest_possible_sentence_length].min
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

    # here we construct @final_sentence_diagram, which is the direct input for SimplerNLG
    @sentence_diagram.each do |k, v| # TODO go deep
      if rephraseables.has_key?(k)
        @final_sentence_diagram[k] = v
      else
        @final_sentence_diagram[k] = @sentence_diagram[k]
      end
    end

    self.realize_sentence(@final_sentence_diagram)
  end

  # recursively explore each Hash/Array to see if it contains anything rephraseable
  # i.e. any lists of things that are not rephraseable
  # they are intentionally not be dup'ed because if rephraseable R contains rephraseable S
  # and if S is rephrased, we want that reflected inside R.
  def _gather_rephraseables(v, keys_so_far)
    if v.respond_to?(:[])
      v.each{|k, subv| gather_rephraseables(subv, [keys_so_far] + [k]) }
    end
    # base case
    if v.respond_to?(:[]) && !v.respond_to?(:has_key?)
      # @rephraseable_keys.push( [keys_so_far] + [k] )

      # deep read
      # (keys_so_far + [k]).reduce(@rephraseables){|memo, interior_key| memo[interior_key] } = v
      # deep write
      (keys_so_far).reduce(@rephraseables){|memo, interior_key| memo[interior_key] }[k] = v
    else
      # do nothing.
      # if we traversed into an array of, say, Strings, we don't care (on this iteration)
      # on the "parent" iteration, we should have added v to the list of rephraseables 
    end
  end

  #{
  # :s => ["Democrats", "Democratic Party"],
  # :number => [2, 1],
  # :v => ["win"], 
  # :perfect => [true],
  # :tense => [:present],
  # :o => [
  #         { :det => 'the', 
  #           :noun => ["presidency", "White House"]
  #         }
  #       ],
  # :negation => [false],


  # this is used after we've made our choices from rephraseables
  # or for intermediate steps, where have intermediate choices
  def self._generate_nlg_diagram(sentence_diagram, rephraseables, keys_so_far=[])
    output = {}
    sentence_diagram.each do |k, v|
      output[k] = rephraseables[k] || sentence_diagram[k]
      if output[k].respond_to?(:[]) && output[k].respond_to?(:has_key?)
        output[k] = _generate_nlg_diagram(output[k], rephraseables[k], keys_so_far + [k])
      end
      raise TypeError, "#{k} ought to have been rephrased, was #{sentence_diagram[k]}" if sentence_diagram[k].respond_to?(:[])
    end


    if v.respond_to?(:[]) && v.respond_to?(:has_key?)
      v.each{|k, subv| _generate_nlg_diagram(v, rephraseables[k]) }
    end
    # base case
    if v.respond_to?(:[]) && !v.respond_to?(:has_key?)
      # @rephraseable_keys.push( [keys_so_far] + [k] )
      @rephraseables[[keys_so_far] + [k]] = v
    else
      # do nothing.
      # if we traversed into an array of, say, Strings, we don't care (on this iteration)
      # on the "parent" iteration, we should have added v to the list of rephraseables 
    end
    output
  end

