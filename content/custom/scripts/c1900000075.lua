-- Team Rocket - Giovanni (Normal Spell)
-- If you control a monster owned by your opponent: Draw 1 card, and if you do, you can make your opponent
-- discard 1 random card. You can only activate 1 "Team Rocket - Giovanni" per turn.
-- PATTERN: "only activate 1 per turn" = SetCountLimit(1,id,EFFECT_COUNT_CODE_OATH) on the activation.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DRAW+CATEGORY_HANDES)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCountLimit(1,id,EFFECT_COUNT_CODE_OATH)
	e1:SetCondition(function(e,tp)
		-- a monster on your field whose owner is your opponent (e.g. taken with Master Ball)
		return Duel.IsExistingMatchingCard(function(c) return c:GetOwner()==1-tp end,tp,LOCATION_MZONE,0,1,nil)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e1:SetOperation(function(e,tp)
		if Duel.Draw(tp,1,REASON_EFFECT)==0 then return end
		local g=Duel.GetFieldGroup(tp,0,LOCATION_HAND)
		if #g>0 and Duel.SelectYesNo(tp,aux.Stringid(id,0)) then   -- Prompt 1
			Duel.BreakEffect()
			Duel.SendtoGrave(g:RandomSelect(tp,1),REASON_EFFECT|REASON_DISCARD)
		end
	end)
	c:RegisterEffect(e1)
end
