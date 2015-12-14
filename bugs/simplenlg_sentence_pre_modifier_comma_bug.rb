require 'simplernlg' if RUBY_PLATFORM == 'java'
NLG = SimplerNLG::NLG

# 136 chars: "Sentence pre have not after 1988 lost the White House in any year when asparagus use grew from the previous election year, besides 2004."
# 135 chars: "Sentence pre has not after 1988 lost the White House in any year when asparagus use grew from the previous election year, besides 2004."

# 135 chars: "In every year when asparagus use grew from the previous election year, besides 2004, sentence pre have since 1988 lost the White House."

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
sentence.add_pre_modifier(since_pp)
sentence.add_front_modifier(prep_phrase)

NLG.realizer.setCommaSepPremodifiers(true) # for pre-modifier sentences
NLG.realizer.setCommaSepCuephrase(true)

expected = "In every year when a condition occured, the Yankees have, since 1999, lost the World Series."
if (output = NLG.realizer.realise_sentence(sentence)) == expected
  puts "incorrect: " + output
  exit 1 
end
# was In every year when a condition occured, the Yankees have since 1999 lost the World Series.
# before 7faf2d8f64b7e3eb001bb6c3ae609274f77f5c25 on my fork of SimpleNLG