require_relative './lib/generate_prediction_data'
require_relative './lib/realize_sentence'

class JeremyMessedUpError < StandardError; end
def with(instance, &block) # ♫ gimme some syntactic sugar, I am your neighbor ♫
  instance.instance_eval(&block)
  instance
end
class Array
  def rephrase
    sample
  end
end
class Hash
  def compact!
    each do |k, v|
      delete(k) if v.nil?
    end
  end
  def compact
    z = self.dup
    z.compact!
    z
  end
end

module PunditBot
  MAX_OUTPUT_LENGTH = 140

  def self.generate_prediction
    if true || __FILE__ != $0 # if called from a library, do this, unless I set my magic false/true variable to choose what I want to happen
      until !(prediction ||= nil).nil?
        pundit = PunditBot.new
        prediction = pundit.generate_prediction
        puts prediction.to_s
        puts prediction.inspect
        prediction = nil if !prediction.nil? && prediction.column_type == "integral" && rand < 0.8
      end
      return prediction
    else # counting prediction types, used to figure out some of these weights
      claim_types = Hash.new(0)
      data_claim_counts = Hash.new(0)
      predictions = []
      loop do 
        pundit = PunditBot.new
        prediction = pundit.generate_prediction
        next if prediction.nil?
                                                                   #0.80 ==> {:integral=>834, :numeric=>290}
        next if prediction.column_type == :integral && rand < 0.80 # exclude 80% of integral claims
        # available methods: dataset, column, column_type
        next if data_claim_counts[prediction.metadata[:data_claim]] > (data_claim_counts.values.reduce(&:+) || 0) / 5.0
        claim_types[prediction.column_type] += 1
        data_claim_counts[prediction.metadata[:data_claim].inspect.split("merrillj")[-1]] += 1
        predictions << prediction.inspect
        predictions.compact!
        predictions.uniq!
        puts predictions.size
        break if predictions.size >= 10 # was 10
      end
      puts claim_types
      puts data_claim_counts
      puts predictions
    end
  end
end

if __FILE__ == $0
  PunditBot.generate_prediction
end

# Since 1975, in every year fake unemployment had declined over the past year, the GOP has  won the presidency save 2012.
# Since 1975, in any year fake unemployment was greater than 2.2, the Republicans has never won the White House.
# Since 1975, the Democrats has not won the White House in any year in which fake unemployment had declined over the past year except 2012.
# Since 1975, in every year fake unemployment ended in an odd number, the Dems has always won the presidency
# Since 1975, the Republican Party has not won the White House in any year in which fake unemployment had grown over the past year save 2012.
# Since 1975, in any year fake unemployment had grown over the past year, the GOP has not won the White House except 2012
# Since 1975, in every year fake unemployment had declined over the past year, the Republicans has  won the White House save 2012.
# Since 1975, the Democratic Party has not won the White House in any year in which fake unemployment had declined over the past year save 2012
# Since 1975, in every year fake unemployment had grown over the past year, the Dems has  won the presidency except 2012
# Since 1975, the Republican Party has always won the presidency in every year in which fake unemployment ended in an even number.
