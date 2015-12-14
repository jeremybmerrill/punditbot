# Democrats should hope for more snow this year... [is this even possible]?

# Democrats should hope Central Park snow increases year over year.

# If you're a Democrat, you should hope that  _________
# Republicans,          you need to hope that DDDDDDD is an even number this year.
# If you're a Democrat, you want              vegetable use to increase this year.


require 'simplernlg'
NLG= SimplerNLG::NLG


party_phrase = NLG.phrase({
  :s => "Democrats",
  :number => :plural,
  :v => 'hope',
  :modal => "should",
  :tense => :present,
})

## this bit should be identical to that used in the other generator.
bears = NLG.factory.create_noun_phrase('bear')
bears.set_feature SimplerNLG::NLG::Feature::NUMBER, SimplerNLG::NLG::NumberAgreement::PLURAL
comp = NLG.phrase({
    :s => bears,
    :v => 'kill',
    :tense => :past,
    :o => 'more than 10 people'
})
pp = NLG.factory.create_preposition_phrase(NLG.factory.create_noun_phrase('this', 'year'))
## end identical bit

party_phrase.add_complement(comp)

modifiers = [:add_post_modifier, :add_front_modifier]
party_phrase.send(modifiers.sample,  pp)

NLG.realizer.setCommaSepCuephrase(true)
sent = NLG.realizer.realise_sentence(party_phrase) 
puts sent

#################

address_phrase = NLG.phrase({
  :s => "you",
  :number => :plural,
  :v => 'need',
  :tense => :present,
})

inner = NLG.phrase({
  :v => "hope"
})

## this bit should be identical to that used in the other generator.
bears = NLG.factory.create_noun_phrase('bear')
bears.set_feature NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL
comp = NLG.phrase({
    :s => bears,
    :v => 'kill',
    :tense => :past,
    :o => 'more than 10 people'
})
pp = NLG.factory.create_preposition_phrase(NLG.factory.create_noun_phrase('this', 'year'))
## end identical bit
inner.add_complement(comp)

modifiers = [:add_post_modifier, :add_front_modifier]
address_phrase.send(modifiers.sample,  pp)
 # SimplerNLG::NLG::Form::IMPERATIVE
inner.set_feature(NLG::Feature::FORM, SimplerNLG::NLG::Form::INFINITIVE)
address_phrase.add_complement(inner)
address_phrase.add_front_modifier("Democrats") # cue phrase

NLG.realizer.setCommaSepCuephrase(true)
sent = NLG.realizer.realise_sentence(address_phrase) 
puts sent

#################


if_phrase = NLG.phrase({
  :s => "you",
  :number => :plural,
  :v => 'hope',
  :modal => "should",
  :tense => :present,
})
## this bit should be identical to that used in the other generator.
bears = NLG.factory.create_noun_phrase('bear')
bears.set_feature SimplerNLG::NLG::Feature::NUMBER, SimplerNLG::NLG::NumberAgreement::PLURAL
comp = NLG.phrase({
    :s => bears,
    :v => 'kill',
    :tense => :past,
    :o => 'more than 10 people'
})
pp = NLG.factory.create_preposition_phrase(NLG.factory.create_noun_phrase('this', 'year'))
## end identical bit

if_phrase.add_complement(comp)

if_phrase.add_front_modifier("if you're a Democrat")

modifiers = [:add_post_modifier, :add_front_modifier]
if_phrase.send(modifiers.sample,  pp)

NLG.realizer.setCommaSepCuephrase(true)
sent = NLG.realizer.realise_sentence(if_phrase) 
puts sent

#############

imperative_phrase = NLG.phrase({
  :number => :plural,
  :v => ['hope', 'pray'].sample,
  :tense => :present,
})

## this bit should be identical to that used in the other generator.
bears = NLG.factory.create_noun_phrase('bear')
bears.set_feature NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL
comp = NLG.phrase({
    :s => bears,
    :v => 'kill',
    :tense => :past,
    :o => 'more than 10 people'
})
pp = NLG.factory.create_preposition_phrase(NLG.factory.create_noun_phrase('this', 'year'))
## end identical bit
imperative_phrase.add_complement(comp)

modifiers = [:add_post_modifier, :add_front_modifier]
imperative_phrase.send(modifiers.sample,  pp)
imperative_phrase.set_feature(NLG::Feature::FORM, SimplerNLG::NLG::Form::IMPERATIVE)
imperative_phrase.add_front_modifier("Democrats") # cue phrase

NLG.realizer.setCommaSepCuephrase(true)
sent = NLG.realizer.realise_sentence(imperative_phrase) 
puts sent
