require 'simplernlg' if RUBY_PLATFORM == 'java'
NLG = SimplerNLG::NLG



# 137 chars: "After 1988 in every year when asparagus use grew from the previous election year, besides 2004, sentence front have lost the White House."
# 136 chars: "After 1988 in any year when asparagus use grew from the previous election year, except 2004, sentence front has not lost the presidency."
# 137 chars: "Since 1988 in every year when asparagus use grew from the previous election year, besides 2004, sentence front have lost the White House."
# 138 chars: "Since 1988 in any year when asparagus use grew from the previous election year, besides 2004, sentence front has not lost the White House."


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
since_pp   .set_feature(NLG::Feature::APPOSITIVE, true)
prep_phrase.set_feature(NLG::Feature::APPOSITIVE, true)
# prep_phrase.add_pre_modifier(since_pp) # does the same thing as sentence.add_front_modifier(since_pp)
sentence.add_front_modifier(since_pp)
sentence.add_front_modifier(prep_phrase)

NLG.realizer.setCommaSepCuephrase(true)

expected = "Since 1999, in every year when a condition occured, the Yankees have lost the World Series."
if (output = NLG.realizer.realise_sentence(sentence)) == expected
  puts "incorrect: " + output
  exit 1 
end

# output, and desired additional commas
# Since 1999 in every year when a condition occured, the Yankees have lost the World Series.
#           ,
# fixed via 5d1252e13a665a29de4243937147c1ab8d2d7346 in my fork of SimpleNLG
# Since 1999, in every year when a condition occured, the Yankees have lost the World Series.
