  def initialize(template)
    split_template = template.split(/([\[\<])/)
    # looks something like ['fragment', '<', 'fragment>', ]
    # we've got to ignore the first, since we want the < to join with the element _after_ it
    template_arr = [split_template[0]] + split_template[1..-1].each_slice(2).map(&:join)
    @prediction = template_arr
    @data = {}
  end

  def templatize!
    @prediction.map! do |template_phrase|
      if (template_key = template_phrase.match( /<([a-zA-Z0-9_]+)>/))
        template_key = template_key[1] # ugh this is inelegant
        puts "Missing key: #{template_key}" unless @data.has_key? template_key
        template_phrase =  @data[template_key].to_s
      else
        template_phrase
      end
    end
  end

  # def templatize!
  #   @template.scan(/<([a-zA-Z0-9_]+)>/).map(&:first).each do |template_phrase|
  #     puts "Missing key: #{template_phrase}" unless @data.has_key? template_phrase
  #     if template_phrase.is_a? Verb
  #       @data["subject"] # the party is always the subject -- FOR NOW #TODO
  #     end
  #     @prediction.gsub!("<#{template_phrase}>", @data[template_phrase].to_s)
  #   end
  # end

  def resolve_options!
    # N.B. a rephrase can be empty if the phrase is optional.
    #TODO: figure out how to do rephrases in a way that's smart about 140 chars
    @prediction.map do |fragment| 
      new_fragment = fragment.clone
      fragment.scan(/\[([^\]]*)\]/).map(&:first).each do |rephrases|
        rephrase = rephrases.split(';', -1).map(&:strip).sample
        new_fragment = new_fragment.gsub("[#{rephrases}]", rephrase)
      end
      new_fragment
    end
  end

  def inflect!
    @prediction.each do |fragment|
      if fragment.is_a? Verb
        # the party is always the subject -- FOR NOW #TODO
        fragment.person(3).number(@data["subject"], number) 
      end
    end
  end

  # problem:
  # we can't inflect until we have a verb and a subject (because English)
  # we don't have a subject until we resolve_options! (because it's in a [] template from party)
  # we can't resolve_options! until we fill in <> templates (because they often include [] templates)
  # we can't join until we've done all of these things
  # 
  # Results: {:data_claim=>"unemployment's digits add up to an odd number", :start_year=>"1976", :exceptional_year=>"1992", :polarity=>false}
  # {"party"=>"[#<Subj:0x007f6c7360a590>;#<Subj:0x007f6c7360a518>;#<Subj:0x007f6c7360a608>]", "subject"=>"[#<Subj:0x007f6c7360a590>;#<Subj:0x007f6c7360a518>;#<Subj:0x007f6c7360a608>]", "politics_verb_phrase"=>"won the [White House; presidency]", "ending"=>", [except; save] 1992", "time_phrase_1"=>#<Verb:0x007f6c733b0858 @by_person=[["have  not", "have  not"], ["have  not", "have  not"], ["has  not", "have  not"]], @by_number=[["have  not", "have  not", "has  not"], ["have  not", "have  not", "have  not"]]>, "time_phrase_2"=>"in any year", "start_year"=>"1976", "data_claim"=>"unemployment's digits add up to an odd number"}
  # punditbot.rb:211:in `to_s': Since 1976 [#<Subj:0x007f6c7360aa40>;#<Subj:0x007f6c7360a8b0>;#<Subj:0x007f6c7360ab08>] #<Verb:0x007f6c73878548> won the [White House; presidency] in every year unemployment's digits add up to an odd number , [except; save] 1992 [.;] (JeremyMessedUpError)
  #   from punditbot.rb:383:in `puts'
  #   from punditbot.rb:383:in `puts'
  #   from punditbot.rb:383:in `<main>'
  # maybe this is the right approach:
  #
  # - make the template a whole lot of template_item objects or strings
  #   template_item objects can get filled in with something else
  #   - either something extraneous, like <> templates
  #   - either something internal (basically just a list of options)
  #   - something that gets resolved at a later stage (like Verbs)
  # probably better to hold off for now though!

######
#
# "Since <start_year>, the <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> in which <data_claim><ending>[.;]",
# "Since <start_year>, <time_phrase_2> <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]",
# "The <party> <time_phrase_1> <politics_verb_phrase> <time_phrase_2> since <start_year> in which <data_claim><ending>[.;]",
# "<time_phrase_2> since <start_year> when <data_claim>, the <party> <time_phrase_1> <politics_verb_phrase><ending>[.;]"
#
#
#
#
#
#
#
#
#



  def capitalize!
    @prediction = @prediction[0].capitalize + @prediction[1..-1]
  end

  def process!
    templatize!
    resolve_options!
    inflect!
    @prediction = @prediction.join(' ')
    @prediction.squeeze! ' '
    capitalize!
  end


  def to_s
    joined_prediction = @prediction.respond_to?(:join) ? @prediction.join('') : @prediction
    raise JeremyMessedUpError, joined_prediction if joined_prediction.include?("<") || joined_prediction.include?("[")
    joined_prediction
  end

  def inspect
    joined_prediction = @prediction.respond_to?(:join) ? @prediction.join('') : @prediction
    raise JeremyMessedUpError, joined_prediction if joined_prediction.include?("<") || joined_prediction.include?("[")
    "#{joined_prediction} (#{joined_prediction.size} chars)"
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
