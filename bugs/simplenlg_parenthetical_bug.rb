require 'simplernlg' if RUBY_PLATFORM == 'java'
NLG = SimplerNLG::NLG

subj = NLG.factory.create_noun_phrase('the', "Yankees")
main_clause = {
  :s => subj,
  :number => 'plural',
  :v => "lost", 
  :perfect => true,
  :tense => :present,
  :o => "the World Series",
}
sentence = NLG.phrase(main_clause)

condition_phrase = NLG.phrase({
                          :s => "a condition",
                          :v => "occur",
                          :tense => :past
                      })
condition_phrase.set_feature(NLG::Feature::COMPLEMENTISER, 'when')
year_np = NLG.factory.create_noun_phrase('every', 'year' )
year_np.add_complement(condition_phrase)
prep_phrase = NLG.factory.create_preposition_phrase('in', year_np)
prep_phrase.set_feature(NLG::Feature::APPOSITIVE, true)



since_pp = NLG.factory.create_preposition_phrase('since', NLG.factory.create_noun_phrase('1999'))
since_pp.   set_feature(NLG::Feature::APPOSITIVE, true)
sentence.add_pre_modifier(since_pp)

sentence.add_pre_modifier(prep_phrase) 


NLG.realizer.setCommaSepPremodifiers(true) # for pre-modifier sentences
puts NLG.realizer.realise_sentence(sentence) 


# output, with expected commas below
# The Yankees have in every year when a condition occured lost the World Series.
#                 ,                                      , 