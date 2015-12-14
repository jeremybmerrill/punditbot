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

since_pp = NLG.factory.create_preposition_phrase('since', NLG.factory.create_noun_phrase('1999'))
since_pp.set_feature(NLG::Feature::APPOSITIVE, true) # responsible for commas 1 and either 2 or 3

prep_phrase.add_post_modifier(since_pp)

except_phrase = NLG.factory.create_preposition_phrase('except', NLG.factory.create_noun_phrase('2001') )
except_phrase.set_feature(NLG::Feature::APPOSITIVE, true) # responsible for comma 2 or 3
prep_phrase.add_post_modifier(except_phrase)

sentence.add_front_modifier(prep_phrase) 

NLG.realizer.setCommaSepCuephrase(true) # responsible for comma 4
puts NLG.realizer.realise_sentence(sentence) 

expected = "In every year when a condition occured, since 1999, except 2001, the Yankees have lost the World Series."

if (output = NLG.realizer.realise_sentence(sentence)) == expected
  puts "incorrect: " + output
  exit 1 
end


# output, with commas numbered
# In every year when a condition occured, since 1999,, except 2001, the Yankees have lost the World Series.
#                                       1           23            4