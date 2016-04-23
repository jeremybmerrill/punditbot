    case [:you, :if, :imperative].sample # removed :bare because it sucks
    when :you
      phrase = NLG.phrase({
        :s => "you",
        :number => :plural,
        :v => 'need',
        :tense => :present,
      })

      inner = NLG.phrase({
        :v => "hope"
      })

      inner.add_complement(@data_phrase)

      party_np = NLG.factory.create_noun_phrase(party_member_name)
      party_np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
      phrase.add_front_modifier(party_np) # cue phrase

      modifiers = [:add_post_modifier, :add_front_modifier]
      phrase.send(modifiers.sample,  pp)
      inner.set_feature(NLG::Feature::FORM, NLG::Form::INFINITIVE)
      phrase.add_complement(inner)
      NLG.realizer.setCommaSepCuephrase(true)
    when :if
      phrase = NLG.phrase({
        :s => "you",
        :number => :plural,
        :v => 'hope',
        :modal => "should",
        :tense => :present,
      })
      phrase.add_complement(@data_phrase)
      phrase.add_front_modifier("if you're a " + party_member_name)
      modifiers = [:add_post_modifier, :add_front_modifier]
      phrase.send(modifiers.sample,  pp)

      NLG.realizer.setCommaSepCuephrase(true)
    when :imperative
      phrase = NLG.phrase({
        :number => :plural,
        :v => ['hope', 'pray'].sample,
        :tense => :present,
      })
      phrase.add_complement(@data_phrase)
      modifiers = [:add_post_modifier, :add_front_modifier]
      phrase.send(modifiers.sample,  pp)
      phrase.set_feature(NLG::Feature::FORM, NLG::Form::IMPERATIVE)
      np = NLG.factory.create_noun_phrase(party_member_name)
      np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
      phrase.add_front_modifier( np ) # cue phrase
      NLG.realizer.setCommaSepCuephrase(true)
    end














party_member_name, claim_polarity = *[[@prediction_meta[:party].member_name, @prediction_meta[:claim_polarity]], [@prediction_meta[:party].member_name.downcase.include?("democrat") ? "Republican" : "Democrat", !@prediction_meta[:claim_polarity]]].sample 

phrase = {
  :s => "you",
  :number => :plural,
  :v => 'need',j
  :tense => :present,# TODO can be other stuff too


  :complements => [
    {
      :v => "hope",
      :complements => [
        @data_phrase.merge({
          tense: :present,
          complementiser: 'that',
          negated: @prediction_meta[:politics_condition].control ? !claim_polarity : claim_polarity
        })
      ],
      :pp => [
        {
          :determiner => 'this',
          :rest => 'year',
          :exclude_positions => [:pre]
        }

      ]
    }
  ]
} 


party_np = NLG.factory.create_noun_phrase(party_member_name)
party_np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
phrase.add_front_modifier(party_np) # cue phrase

inner.set_feature(NLG::Feature::FORM, NLG::Form::INFINITIVE)
phrase.add_complement(inner)
NLG.realizer.setCommaSepCuephrase(true)
