-- Vaporeon
-- You can Special Summon this card (from your Deck) by Tributing 1 "Eevee" and discarding 1 "Water Stone".
-- You can Special Summon this card from your hand by Tributing 1 "Eevee" from your hand or field, or by banishing
-- 1 "Eevee" from your GY. You can only Special Summon "Vaporeon" once per turn.
-- Your opponent cannot target WATER monsters you control for attacks, except this one.
-- Gains 300 DEF for each other WATER monster on the field.
-- During your Standby Phase: Gain 500 LP for each other WATER monster on the field.
local s,id=GetID()
s.listed_names={CARD_EEVEE,CARD_WATER_STONE}
function s.initial_effect(c)
	Pokemon.AddEeveelution(c,CARD_WATER_STONE)
	-- Only this card can be attacked among your WATER monsters
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_SELECT_BATTLE_TARGET)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetValue(function(e,tc) return tc~=e:GetHandler() and tc:IsFaceup() and tc:IsAttribute(ATTRIBUTE_WATER) end)
	c:RegisterEffect(e1)
	-- +300 DEF per other WATER monster
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_UPDATE_DEFENSE)
	e2:SetValue(function(e) return 300*s.others(e:GetHandler()) end)
	c:RegisterEffect(e2)
	-- Standby: +500 LP per other WATER monster
	local e3=Effect.CreateEffect(c)
	e3:SetCategory(CATEGORY_RECOVER)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) and s.others(e:GetHandler())>0 end)
	e3:SetOperation(function(e,tp) Duel.Recover(tp,500*s.others(e:GetHandler()),REASON_EFFECT) end)
	c:RegisterEffect(e3)
end
function s.others(c)
	return Duel.GetMatchingGroupCount(function(x) return x:IsFaceup() and x:IsAttribute(ATTRIBUTE_WATER) end,0,LOCATION_MZONE,LOCATION_MZONE,c)
end
