PunditBot
=========

> "Duke hasn't defeated Carolina at home on a rainy Thursday since 1872!" - some sportscaster, probably

> "The Democrats haven't won the White House without winning Iowa in a year when someone named Obama wasn't running since 1824." - some pundit, probably

These claims are stupid. They have no predictive power. Let's mock them.

TODO:
  - should `The Republicans have in every year bears killed more than 10 people won the White House.` have commas or switch `have` and the complement, e.g. `The Republicans, in every year bears killed more than 10 people, have won the White House.`?
  - commas and dashes
  - how to make numeric claims drop down to integral
  - ensure NLG system generates all varieties that were templated out.
  - remove linguistics stuff from everything NLG parts (so there's no "verb phrase" in constants)
  - MAYBE: add support for candidate based exceptoins ("Without a Clinton on the ballot, ")
  - make categories that react to previous years
  - should I add units (to correlates.yml)
  - twitter/140char-ification
  - put alternate nouns in correlates.yml (e.g. ["average annual U.S. temperature", "avg. U.S. temperature"] )
  - boolean type (e.g. "had a trade deficit")

Leave this for later, focus on MVP:
    - add categorical data sets (how does this work??)
