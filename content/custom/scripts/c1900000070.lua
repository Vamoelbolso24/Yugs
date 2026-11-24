-- Parasect
-- Evolution Summon from "Paras" (hard once per turn).
-- When Summoned this way: You can shuffle 1 monster your opponent controls into the Deck. (Doesn't target.)
-- PATTERN: "if Summoned this way" = EVENT_SPSUMMON_SUCCESS + Pokemon.IsEvolutionSummoned(c) (like Charmeleon).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000069)   -- from Paras

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TODECK)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e) return Pokemon.IsEvolutionSummoned(e:GetHandler()) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsAbleToDeck,tp,0,LOCATION_MZONE,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TODECK,nil,1,1-tp,LOCATION_MZONE)
	end)
	e1:SetOperation(function(e,tp)
		-- chosen now, when it resolves (not a target)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TODECK)
		local g=Duel.SelectMatchingCard(tp,Card.IsAbleToDeck,tp,0,LOCATION_MZONE,1,1,nil)
		if #g>0 then
			Duel.HintSelection(g)
			Duel.SendtoDeck(g,nil,SEQ_DECKSHUFFLE,REASON_EFFECT)   -- shuffled into its owner's Deck
		end
	end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000069}
