require 'simplernlg' if RUBY_PLATFORM == 'java'
NLG = SimplerNLG::NLG

subj = NLG.factory.create_noun_phrase('I')
obj = NLG.factory.create_noun_phrase('defect') 
obj.set_feature NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL
possessive = NLG.factory.create_noun_phrase("the", "use") 
possessive.add_pre_modifier("fresh tomato")
# possessive.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::SINGULAR)
possessive.set_plural(false);
possessive.set_feature(NLG::Feature::POSSESSIVE, true)
obj.set_specifier(possessive)
obj

main_clause = {
  :s => subj,
  :v => "count up", 
  :perfect => true,
  :tense => :present,
  :o => obj
}
sentence = NLG.phrase(main_clause)

expected = "I have counted up fresh tomatoes use's digits."

if (output = NLG.realizer.realise_sentence(sentence)) != expected
  puts "incorrect: " + output
  exit 1 
end


# output, with commas numbered
# In every year when a condition occured, since 1999,, except 2001, the Yankees have lost the World Series.
#                                       1           23            4