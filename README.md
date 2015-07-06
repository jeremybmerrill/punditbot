PunditBot
=========

> "Duke hasn't defeated Carolina at home on a rainy Thursday since 1872!" - some sportscaster, probably

> "The Democrats haven't won the White House without winning Iowa in a year when someone named Obama wasn't running since 1824." - some pundit, probably

These claims are stupid. They have no predictive power. Let's mock them.

TODO:
  - add "Every year BUT 1992"
  DO NOW: 
  - refactor
  - weather, temperature on election day
  - somehow balance out distribution of integral, numeric, claims {:integral=>2789, :numeric=>757} from 10k
                                                                  {:integral=>2697, :numeric=>740}
  - looks like a polarity issue 124 chars: "Starting in 1988, in every year fresh carrot use ended in an odd number, the Democratic Party has never lost the presidency."
  - Do I even need this Noun class? Will the Lexicon thing deal with noun number for me?
  - get Senate/House control database


Leave this for later, focus on MVP:
    - add categorical data sets (how does this work??) {:s => "weather", :v => 'is', :o => "rainy"} {:s => "Super Bowl winner", :v => 'is', :o => "the Patriots"}
    - commas and dashes (fixed, but for bugs, e.g. https://github.com/simplenlg/simplenlg/issues/13 )
    - state based "without winning Iowa or Pennsylvania"
    - MAYBE: add support for candidate based exceptoins ("Without a Clinton on the ballot, ")
    - boolean type (e.g. "had a trade deficit")?? ( already in correlates.yml )
  - can I make a hash that represents a whole sentence?? (then isolate linguistics stuff)
