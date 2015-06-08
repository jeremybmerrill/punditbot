PunditBot
=========

> "Duke hasn't defeated Carolina at home on a rainy Thursday since 1872!" - some sportscaster, probably

> "The Democrats haven't won the White House without winning Iowa in a year when someone named Obama wasn't running since 1824." - some pundit, probably

These claims are stupid. They have no predictive power. Let's mock them.

TODO:
  - should `The Republicans have in every year bears killed more than 10 people won the White House.` have commas or switch `have` and the complement, e.g. `The Republicans, in every year bears killed more than 10 people, have won the White House.`?
  - how to make numeric claims drop down to integral
  - ensure NLG system generates all varieties that were templated out.
  - remove linguistics stuff from everything NLG parts (so there's no "verb phrase" in constants)
  - MAYBE: add support for candidate based exceptoins ("Without a Clinton on the ballot, ")
  - make categories that react to previous years
  - uh oh: 95 chars: "When per-capita fresh snap/green beans use, the Republican Party has never lost the presidency.", 105 chars: "The Republican Party has never, in years when per-capita fresh snap/green beans use lost the White House."
  - add "Every year BUT 1992"
  - in every year EXCEPT 1234 **that** X. Need to add **that** if there's an intrusive parenthetical
  DO NOW: 
  - should I add units (to correlates.yml, e.g. "degrees"; just a list of units that are either prepended/appended)
  - boolean type (e.g. "had a trade deficit")
  - put alternate nouns in correlates.yml (e.g. ["average annual U.S. temperature", "avg. U.S. temperature"] ) / make it rephraseable



Leave this for later, focus on MVP:
    - add categorical data sets (how does this work??)
    - commas and dashes (fixed, but for bugs, e.g. https://github.com/simplenlg/simplenlg/issues/13 )
