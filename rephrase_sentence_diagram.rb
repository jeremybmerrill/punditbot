OUTPUT_OF_GENERATE_PREDICTION_DATA = {
  :s => ["Democrats", "Democratic Party"],
  :number => [2, 1],
  :v => ["win"], 
  :perfect => [true],
  :tense => [:present],
  :o => [
          { :det => 'the', 
            :noun => ["presidency", "White House"]
          }
        ],
  :negation => [false],
  :prepositional_phrases => [
    [{
      :preposition => ['since', 'after', 'starting in'],
      :rest => ["1992"],
      :appositive => true, # maybe this should just check for whether it's a word or more than one word
      :exclude_positions => [[]]
    }],
    [{
      :preposition => "in",
      :rest => [{
                :subject => {
                  :determiner => ['every'], # generate_prediction_data should just put either 'every' or 'any' here
                  :noun => ["year", "election year"],
                },
                :complements => [
                  {
                    :s => ["unemployment", "the unemployment rate"],
                    :v => 'be',
                    :tense => :past,
                    :o => "greater",
                    :prepositional_phrases => [{
                      :preposition => ["than"],
                      :o => [{
                          :noun => "7.8",
                          :template_string => "$%.2f/sq. in."
                        }]
                      }],
                    :complementizer => ["when"]
                  }
                ],
              }],
      :appositive => [true],
      :exclude_positions => [[]]
    }],
    [{
      :preposition => ['except', 'besides'],
      :rest => ["1992"],
      :force_position => ["post"],
      :appositive => [true],
    }]
  ]
}

class Hash
  def self.recursive
    new { |hash, key| hash[key] = recursive }
  end
  def deep_read(keys)
    (keys).reduce(@rephraseables){|memo, interior_key| memo[interior_key] }
  end
  def deep_write(keys, v)
    (keys[0...-1]).reduce(self){|memo, interior_key| memo[interior_key] }[keys[-1]] = v
  end
end


@rephraseable_keys = []
@rephraseables = Hash.recursive
# gather_rephraseables
# determine "buffer" amount
#   1. replace all one-member arrays in the @rephraseable hash with single arrays (in gather_rephraseables)
#   2. figure out max/min for all members.
#      a. create an optional base case.
#      b. fully realize all non-string member arrays
#   3. 

def get_rid_of_single_member_arrays(v, keys_so_far)
  if v.is_a?(Hash) || v.is_a?(Array)
    v.each{|k, subv| next if subv.nil?; get_rid_of_single_member_arrays(subv, [keys_so_far] + [k]) }
  end
  # base case
  if v.respond_to?(:sample) && !v.respond_to?(:has_key?) 
    el = (keys_so_far[0...-1]).reduce(OUTPUT_OF_GENERATE_PREDICTION_DATA){|memo, interior_key| memo[interior_key] }
    if el[keys_so_far[-1]].size == 1
      el[keys_so_far[-1]] = v[0]
    end
  end
end

def gather_rephraseables(v, keys_so_far)
  if v.is_a?(Hash) || v.is_a?(Array)
    v.each{|k, subv| next if subv.nil?; puts "recursing #{k}"; gather_rephraseables(subv, [keys_so_far] + [k]) }
  end
  # base case
  if v.respond_to?(:sample) && !v.respond_to?(:has_key?) # array but not hash
    # @rephraseable_keys.push( [keys_so_far] + [k] )

    # JUST FYI:
    # deep read
    # (keys_so_far + [k]).reduce(@rephraseables){|memo, interior_key| memo[interior_key] } = v
    # deep write
                                                                                                              # if v is a one-member hash, just put in the first member
    (keys_so_far[0...-1]).reduce(@rephraseables){|memo, interior_key| memo[interior_key] }[keys_so_far[-1]] = v.size == 1 ? v[0] : v
  else
    puts "doing nothing from #{v}"
    # do nothing.
    # if we traversed into an array of, say, Strings, we don't care (on this iteration)
    # on the "parent" iteration, we should have added v to the list of rephraseables 
  end
end

def fill_in_rephrase_choices(sentence_diagram, rephrase_options)
  output = Hash.recursive
  sentence_diagram.each do |k, v|
    fill_in(output, )
  end
end

# find everything rephraseable in the sentence_diagram
# so we get a flat list
# or recursively loop throughj??

# we want to find every Array in @sentence_diagram
# and put it in rephraseables (keeping track of where it belongs)
OUTPUT_OF_GENERATE_PREDICTION_DATA.each{|k, v| get_rid_of_single_member_arrays(v, [k]) }
OUTPUT_OF_GENERATE_PREDICTION_DATA.each{|k, v| gather_rephraseables(v, [k]) }


puts @rephraseables

raise IOError, "done"

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

def self.realize_sentence(sentence_diagram)
  SimplerNLG::NLG.render(sentence_diagram)
end

# recursively explore each Hash/Array to see if it contains anything rephraseable
# i.e. any lists of things that are not rephraseable
# they are intentionally not be dup'ed because if rephraseable R contains rephraseable S
# and if S is rephrased, we want that reflected inside R.


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
    if output[k].respond_to?(:[]) || output[k].respond_to?(:has_key?)
      output[k] = _generate_nlg_diagram(output[k], rephraseables[k], keys_so_far + [k])
    end
    raise TypeError, "#{k} ought to have been rephrased, was #{sentence_diagram[k]}" if sentence_diagram[k].respond_to?(:[])
  end


  if v.respond_to?(:sample) || v.respond_to?(:has_key?)
    v.each{|k, subv| _generate_nlg_diagram(v, rephraseables[k]) }
  end
  # base case
  if v.respond_to?(:sample) || !v.respond_to?(:has_key?)
    # @rephraseable_keys.push( [keys_so_far] + [k] )
    @rephraseables[[keys_so_far] + [k]] = v
  else
    # do nothing.
    # if we traversed into an array of, say, Strings, we don't care (on this iteration)
    # on the "parent" iteration, we should have added v to the list of rephraseables 
  end
  output
end


