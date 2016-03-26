PunditBot
=========

> "Duke hasn't defeated Carolina at home on a rainy Thursday since 1872!" - some sportscaster, probably

> "The Democrats haven't won the White House without winning Iowa in a year when someone named Obama wasn't running since 1824." - some pundit, probably

These claims are stupid. They have no predictive power. Let's mock them.



TODO:

  DO NOW: 
  - miles traveled (RITA file in data, http://www.rita.dot.gov/bts/sites/rita.dot.gov.bts/files/publications/national_transportation_statistics/html/table_01_40.html)
  - updated vegetable figures?
  - just be careful to note SOMEWHERE that 2014 vegetable figures are a prediction
  - add airline delays, amtrak stations served, oil prices (http://www.eia.gov/dnav/pet/pet_pri_spt_s1_a.htm)
fix Democrats, you need to hope that unemployment's digits add not up to an odd number this year.



Leave this for later, focus on MVP:
    - add categorical data sets (how does this work??) {:s => "weather on election day", :v => 'is', :o => "rainy"} {:s => "the Super Bowl winner", :v => 'is', :o => "the Patriots"}
    - commas and dashes (fixed, but for bugs, e.g. https://github.com/simplenlg/simplenlg/issues/13 )
    - state based "without winning Iowa or Pennsylvania"
    - MAYBE: add support for candidate based exceptions ("Without a Clinton on the ballot, ")
    - boolean type (e.g. "had a trade deficit", "was warmer than usual")?? ( already in correlates.yml )
  - can I make a hash that represents a whole sentence?? (then isolate linguistics stuff)
  - Do I even need this Noun class? Will the Lexicon thing deal with noun number for me?
  - Replace binary logic with ternary, so we can deal with both-houses-of-Congress control, which can be R, D or Split
  - replace units prefix/suffix thing with a template string, to allow to specify something like "$7.55/oz"
  - find or make a better oil price (Fred's is 1940s-2013, and another is 1986-pres, neither of which is great)

Fred is a great source for data to feed to PunditBot:
https://alfred.stlouisfed.org/category?cid=32217&et=&pageID=3&t=
https://github.com/mortada/fredapi apparently could filter out datasets by dates of first (before 1980) and last (2015ish) observation