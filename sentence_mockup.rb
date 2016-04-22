output_of_generate_prediction_data = {
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


template_for_how_generate_prediction_data_creates_the_output_above = {
  :s => party_word.word,
  :number => party_word.number,
  :v => @prediction_meta[:politics_condition].verb, 
  :perfect => true,
  :tense => :present,
  :o => NLG.factory.create_noun_phrase('the', rephraseables[:politics_condition_object].first.word),
  :negation => !claim_polarity
  :prepositional_phrases => [ # these should be randomly assigned as modifiers
    {
      :preposition => rephraseables[:since_after]
      :rest => NLG.factory.create_noun_phrase(@prediction_meta[:start_year]),
      :appositive => true # maybe this should just check for whether it's a word or more than one word
      :position => [:pre, :post, :front]
    },
    {
      :preposition => "in",
      :rest => [{
                :determiner => claim_polarity ? 'every' : 'any',
                :noun => rephraseables[:year_election].first,
                :complements => [{
                    :s => "example complement subject noun, provided as an argument"
                    :complementizer => "when", # NLG::Feature::COMPLEMENTISER, 'when' # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG


                    # this is an example DataClaim template, taken directly from generate_prediction_data.rb
                    :v => 'be',
                    :tense => :past,
                    :o => ["greater"],
                    :prepositional_phrases => [{
                      :preposition => "than",
                      :rest => @dataset.add_units(" than", trues.map{|a, b| b}.min)
                    }],

                }.merge(@data_claim.template)],
              }],
      :rest => {
                :determiner => 'every', # generate_prediction_data should just put either 'every' or 'any' here
                :noun => "year",
                :complements => [{
                    :s => "the unemployment rate",
                    :v => 'be',
                    :tense => :past,
                    :o => "greater",
                    :prepositional_phrases => [{
                      :preposition => "than",
                      :rest => {
                          :noun => "7.8",
                          :template_string => "$%.2f/sq. in."
                      }
                    }],
                    :complementizer => "when"
                  }
                ]
              },




      :appositive => true,
      :position => [:pre, :post, :front]
    },
    {
      :preposition => rephraseables[:except],
      :rest => , NLG.factory.create_noun_phrase(exceptional_year),
      :appositive => true,
      :position => [:post]
    }
  ]
}

after_going_through_rephrase = {
  :s =>{
    :determiner => "the",
    :noun => "Democratic Party", 
    }, 
  :number =>  1,
  :v => "win", 
  :perfect => true,
  :tense => :present,
  :o =>  {
    :det => 'the', 
    :noun => "presidency"
  },
  :negation => false,
  :prepositional_phrases => [{
      :preposition => 'after',
      :rest => "1992",
      :appositive => true, # maybe this should just check for whether it's a word or more than one word
      :position => :front,
    },
    {
      :preposition => "in",
      :rest => {
                :determiner => 'every', # generate_prediction_data should just put either 'every' or 'any' here
                :noun => "year",
                :complements => [{
                    :s => "the unemployment rate",
                    :v => 'be',
                    :tense => :past,
                    :o => "greater",
                    :prepositional_phrases => [{
                      :preposition => "than",
                      :rest => {
                          :noun => "7.8",
                          :template_string => "$%.2f/sq. in."
                      }
                    }],
                    :complementizer => "when"
                  }
                ]
              },
      :appositive => true,
      :position => :front
    },
    {
      :preposition => 'except',
      :rest => "1992",
      :position => "post",
      :appositive => true,
    }
  ]
}; SimplerNLG::NLG.render(after_going_through_rephrase)

z = {
  :s => {
    :determiner => "the",
    :noun => "Democratic Party", 
    },
  :number =>  1,
  :v => "win", 
  :perfect => true,
  :tense => :present,
  :o =>  {
    :det => 'the', 
    :noun => "presidency"
    },
  :negation => true, 
  :prepositional_phrases => [{
      :preposition => 'after',
      :rest => "1992",
      :appositive => true, # maybe this should just check for whether it's a word or more than one word
      :position => [:pre, :post, :front].sample,
    },
    {
      :preposition => "in",
      :rest => {
                :determiner => 'every', # generate_prediction_data should just put either 'every' or 'any' here
                :noun => "year",
                :complements => [{
                    :s => "the unemployment rate",
                    :v => 'be',
                    :tense => :past,
                    :o => "greater",
                    :prepositional_phrases => [{
                        :preposition => "than",
                        :rest => {
                            :noun => "7.8",
                            :template_string => "$%.2f/sq. in."
                        }
                    }],
                    :complementizer => "when"
                  }
                ],
                :prepositional_phrases => [
                  {
                    :preposition => 'except in',
                    :rest => "1992",
                    :position => :post,
                    :appositive => true,
                  }
                ]
              },
      :appositive => true,
      :position =>  [:pre, :post, :front].sample
    }
  ]
}; SimplerNLG::NLG.render(z)

