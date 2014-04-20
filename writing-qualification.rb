require 'json' ; require_relative '../turk-rest-api/sql' ; require_relative 'turk-credentials'
Q = eval(File.read("quals.json"))
Q["chooseBetter"] = {}
def question_for_rewrite(rw) {"Text" => {"questionText" => "Please rewrite the following passage by correcting any mistakes.\n\n#{rw}", "defaultText" => rw }} end
def question_for_chooseBetter(cb) {"Radio" => {"questionText" => "Given the choice between word1 and word2 (written as '{{1 word1 [or] word2 2}}'), please choose the word that fits better.\n#{cb}", "chooseOne" => ["1","2"]}} end

Rewrites = Q["rewrites"].map {|rw, rgx| question_for_rewrite(rw) }
ChooseBetter = Q["chooseBetter"].map {|cb, rgx| question_for_chooseBetter(cb) }
Instructions = 'Please proofread the following text.' # (No majority-rules rejections, no blocking.)'
DistinctUsers = 20
AddMinutes = 0
Cost = nil
KnownAnswerQuestions = nil
UniqueAskId = 'EarlyOctober2013'

PercentagesCorrect = [(99..100), (98..99)] # , (95..98)]
AnsweredQuestionCount = [(200..500), (2000..4000), (10000..50000)]

def qualification_for_pct_correct_and_answered_count(pctlo, pcthi, countlo, counthi)
  {"QualificationRequirement.1.QualificationTypeId" => "000000000000000000L0", "QualificationRequirement.1.Comparator" => "GreaterThan", "QualificationRequirement.1.IntegerValue" => pctlo.to_s, "QualificationRequirement.2.QualificationTypeId" => "000000000000000000L0", "QualificationRequirement.2.Comparator" => "LessThanOrEqualTo", "QualificationRequirement.2.IntegerValue" => pcthi.to_s, "QualificationRequirement.3.QualificationTypeId" => "00000000000000000040", "QualificationRequirement.3.Comparator" => "GreaterThan", "QualificationRequirement.3.IntegerValue" => countlo.to_s, "QualificationRequirement.4.QualificationTypeId" => "00000000000000000040", "QualificationRequirement.4.Comparator" => "LessThanOrEqualTo", "QualificationRequirement.4.IntegerValue" => counthi.to_s}
end

def put_all
  (Rewrites+ChooseBetter).each {|q|
    PercentagesCorrect.each {|pcr|
      AnsweredQuestionCount.each {|aqcr|
        put_question_type_and_question_and_ask!(Instructions, q, DistinctUsers, AddMinutes, Cost, KnownAnswerQuestions, UniqueAskId, JSON.dump(qualification_for_pct_correct_and_answered_count(pcr.first, pcr.last, aqcr.first, aqcr.last).merge({"Reward.1.Amount" => "0.5"})), DB)
      }
    }
  }
end

def ship_one() ship_oldest_batch!(DB, Turk[:live_endpoint], Turk[:access], Turk[:secret_access], TurkQueue[:research_endpoint]) end
def poll_mine() consume_assignments!(DB, TurkQueue[:research_endpoint], TurkQueue[:access], TurkQueue[:secret_access], Turk[:live_endpoint], Turk[:access], Turk[:secret_access]) end

def puts_results()
  Q['rewrites'].each {|rw, rgx|
    PercentagesCorrect.each {|pcr|
      AnsweredQuestionCount.each {|aqcr|
        answers = get_answers(Instructions, question_for_rewrite(rw), DistinctUsers, AddMinutes, Cost, KnownAnswerQuestions, UniqueAskId, JSON.dump(qualification_for_pct_correct_and_answered_count(pcr.first, pcr.last, aqcr.first, aqcr.last).merge({"Reward.1.Amount" => "0.5"})), DB)
        next unless answers[0]
        answers[1].each {|a|
          puts a["Pass"]["worker"]+"|"+a["Pass"]["value"].match(rgx).to_a[1..-1].to_a.compact.length.to_s
        }
      }
    }
  }
end

puts_results
