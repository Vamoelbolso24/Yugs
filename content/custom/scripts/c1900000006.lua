-- Charmeleon
-- Evolution Summon from "Charmander". If Summoned this way: You can draw 1 card, then discard 1 card.
-- PATTERN: "If Summoned this way: You can ..." = optional trigger on EVENT_SPSUMMON_SUCCESS
-- with the condition Pokemon.IsEvolutionSummoned. Copy e1 for any Pokemon with an on-evolve effect.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000005)   -- EVOLUTION SUMMON from Charmander

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))      -- Prompt 1
	e1:SetCategory(CATEGORY_DRAW+CATEGORY_HANDES)   -- HANDES = discarding from hand
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)  -- optional ("You can") trigger about this card
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)         -- after this card is Special Summoned...
	e1:SetProperty(EFFECT_FLAG_DELAY)          -- "If" (not "When"): it can't miss the timing
	e1:SetCondition(function(e) return Pokemon.IsEvolutionSummoned(e:GetHandler()) end)  -- ...by Evolution Summon
	e1:SetTarget(s.drtg)
	e1:SetOperation(s.drop)
	c:RegisterEffect(e1)
end
s.listed_names={1900000005}

function s.drtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	Duel.SetOperationInfo(0,CATEGORY_HANDES,nil,0,tp,1)
end
function s.drop(e,tp,eg,ep,ev,re,r,rp)
	if Duel.Draw(tp,1,REASON_EFFECT)>0 then   -- only discard if the draw happened
		Duel.ShuffleHand(tp)
		Duel.BreakEffect()                      -- "then": the two actions don't happen at the same time
		Duel.DiscardHand(tp,nil,1,1,REASON_EFFECT+REASON_DISCARD)
	end
end
