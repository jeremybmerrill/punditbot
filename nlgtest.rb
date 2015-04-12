require 'simplernlg'
nlg = SimplerNLG::NLG

# the republicans
# won the white house
# in every year that bears killed more than 10 people

phrase = nlg.phrase({
  :s => 'the Republicans', # nlg.factory.create_noun_phrase('the', 'Republican'), 
  :number => :plural,
  :v => 'win',
  :perfect => true,
  :tense => :present,
  :o => nlg.factory.create_noun_phrase('the', 'White House')
})
bears = nlg.factory.create_noun_phrase('bear')
bears.set_feature SimplerNLG::NLG::Feature::NUMBER, SimplerNLG::NLG::NumberAgreement::PLURAL
comp = nlg.phrase({
    :s => bears,
    :v => 'kill',
    :tense => :past,
    :o => 'more than 10 people'
})
pp = nlg.factory.create_preposition_phrase('in', nlg.factory.create_noun_phrase('every', 'year'))
pp.add_post_modifier(comp)

modifiers = [:add_post_modifier, :add_pre_modifier, :add_front_modifier]
# phrase.add_post_modifier pp
# The Republicans have won the White House in every year bears killed more than 10 people.
# phrase.add_pre_modifier pp
# The Republicans have in every year bears killed more than 10 people won the White House.
phrase.send(modifiers.sample,  pp)
# In every year bears killed more than 10 people the Republicans have won the White House.



sent = nlg.realizer.realise_sentence(phrase) 
puts sent

# comp = nlg.factory.create_clause();
# comp.set_subject('bears');
# comp.set_verb_phrase('kill');
# comp.set_object(this.man);
