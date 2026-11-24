-- Team Rocket - Master Ball (Normal Trap)
-- Take control of 1 Pokemon monster your opponent controls until the end of your next turn.
-- (Chosen when it resolves, not targeted.)
-- PATTERN: Duel.GetControl(card, new controller, PHASE_END, how many End Phases until it comes back).
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_CONTROL)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.filter,tp,0,LOCATION_MZONE,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_CONTROL,nil,1,1-tp,LOCATION_MZONE)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_CONTROL)
		local tc=Duel.SelectMatchingCard(tp,s.filter,tp,0,LOCATION_MZONE,1,1,nil):GetFirst()
		if not tc then return end
		Duel.HintSelection(tc)
		-- "until the end of your next turn": in your turn that's 3 End Phases away (this one, theirs,
		-- your next); in your opponent's turn it's 2 (theirs, your next).
		Duel.GetControl(tc,tp,PHASE_END,Duel.IsTurnPlayer(tp) and 3 or 2)
	end)
	c:RegisterEffect(e1)
end
function s.filter(c)
	return c:IsFaceup() and c:IsSetCard(SET_POKEMON) and c:IsControlerCanBeChanged()
end
