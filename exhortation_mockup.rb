@data_phrase
party_member_name, claim_polarity = *[[@prediction_meta[:party].member_name, @prediction_meta[:claim_polarity]], [@prediction_meta[:party].member_name.downcase.include?("democrat") ? "Republican" : "Democrat", !@prediction_meta[:claim_polarity]]].sample 
@data_phrase.set_feature(NLG::Feature::TENSE, NLG::Tense::PRESENT)
# @data_phrase.set_feature(NLG::Feature::SUPRESSED_COMPLEMENTISER, true)
@data_phrase.set_feature(NLG::Feature::COMPLEMENTISER, 'that') # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG
@data_phrase.set_feature(NLG::Feature::NEGATED,  @prediction_meta[:politics_condition].control ? !claim_polarity : claim_polarity)

pp = NLG.factory.create_preposition_phrase(NLG.factory.create_noun_phrase('this', 'year'))

{
  :s => "you",
  :number => :plural,
  :v => 'need',j
  :tense => :present,
}

inner = NLG.phrase({
  :v => "hope",
  :complement => @data_phrase
})

party_np = NLG.factory.create_noun_phrase(party_member_name)
party_np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
phrase.add_front_modifier(party_np) # cue phrase

modifiers = [:add_post_modifier, :add_front_modifier]
phrase.send(modifiers.sample,  pp)
inner.set_feature(NLG::Feature::FORM, NLG::Form::INFINITIVE)
phrase.add_complement(inner)
NLG.realizer.setCommaSepCuephrase(true)
