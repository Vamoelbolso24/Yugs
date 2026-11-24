-- Dragonair
-- You can Special Summon this card from your hand by Tributing 1 "Dratini" from your hand or field, or by banishing
-- 1 "Dratini" from your GY. You can only Special Summon "Dragonair" once per turn this way.
-- Once per turn: You can change this card to face-down Defense Position.
-- If this card is flipped face-up: You can target 1 other monster you control; it cannot be destroyed by card
-- effects until the end of this turn.
local s,id=GetID()
s.listed_names={1900000223}
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000223)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_POSITION)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return c:IsCanTurnSet() end
		Duel.SetOperationInfo(0,CATEGORY_POSITION,c,1,0,0)
	end)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) and c:IsFaceup() then Duel.ChangePosition(c,POS_FACEDOWN_DEFENSE) end
	end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e2:SetProperty(EFFECT_FLAG_DELAY+EFFECT_FLAG_CARD_TARGET)
	e2:SetCode(EVENT_FLIP)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		local c=e:GetHandler()
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and chkc~=c end
		if chk==0 then return Duel.IsExistingTarget(nil,tp,LOCATION_MZONE,0,1,c) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,nil,tp,LOCATION_MZONE,0,1,1,c)
	end)
	e2:SetOperation(function(e)
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) then
			local e1=Effect.CreateEffect(e:GetHandler())
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
			e1:SetValue(1)
			e1:SetReset(RESETS_STANDARD_PHASE_END)
			tc:RegisterEffect(e1)
		end
	end)
	c:RegisterEffect(e2)
end
