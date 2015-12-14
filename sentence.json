main_clause = {
  :s => subj,
  :number => party_word.number,
  :v => @prediction_meta[:politics_condition].verb, 
  :perfect => true,
  :tense => :present,
  :o => NLG.factory.create_noun_phrase('the', rephraseables[:politics_condition_object].first.word),
  :negation => !claim_polarity
  :prepositional_phrase => [ # these should be randomly assigned as modifiers
    {
      :preposition => rephraseables[:since_after]
      :rest => NLG.factory.create_noun_phrase(@prediction_meta[:start_year]),
      :appositive => true # maybe this should just check for whether it's a word or more than one word
      :exclude_positions => []
    },
    {
      :preposition => "in",
      :rest => [{
                :type => "noun",
                :determiner => claim_polarity ? 'every' : 'any',
                :noun => rephraseables[:year_election].first,
                :complements => [
                  {
                    :s => "example complement subject noun, provided as an argument"
                    # this is an example DataClaim template
                    :v => 'be',
                    :tense => :past,
                    :o => @dataset.add_units("greater than", trues.map{|a, b| b}.min) # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
                    :complementizer => "when" # NLG::Feature::COMPLEMENTISER, 'when' # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG
                  }
                ],
                :prepositional_phrase => {
                  :preposition => rephraseables[:except],
                  :rest => , NLG.factory.create_noun_phrase(exceptional_year),
                  :appositive => true,
                  :force_position => ["post"]
                }
              }],
      :appositive => true,
      :exclude_positions => []
    }
  ]
}
