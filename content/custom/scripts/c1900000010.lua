-- Blastoise
-- Evolution Summon from "Wartortle".
-- Once per turn (Quick Effect): You can change this card from Attack Position to Defense Position.
-- PATTERN: a Quick Effect = EFFECT_TYPE_QUICK_O + EVENT_FREE_CHAIN (usable in either player's turn,
-- including in response to an attack).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000009)   -- EVOLUTION SUMMON from Wartortle

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_POSITION)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetHintTiming(0,TIMING_ATTACK+TIMINGS_CHECK_MONSTER)  -- tells the game good moments to offer it
	e1:SetCondition(function(e) local c=e:GetHandler() return c:IsAttackPos() and c:IsCanChangePosition() end)
	e1:SetOperation(s.posop)
	c:RegisterEffect(e1)
end
s.listed_names={1900000009}

function s.posop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) and c:IsFaceup() and c:IsAttackPos() then
		Duel.ChangePosition(c,POS_FACEUP_DEFENSE)
	end
end
