-- Flareon
-- You can Special Summon this card (from your Deck) by Tributing 1 "Eevee" and discarding 1 "Fire Stone".
-- You can Special Summon this card from your hand by Tributing 1 "Eevee" from your hand or field, or by banishing
-- 1 "Eevee" from your GY. You can only Special Summon "Flareon" once per turn.
-- Gains 300 ATK for each other FIRE monster on the field.
-- If this card attacks a Defense Position monster, inflict piercing battle damage to your opponent.
-- During your Standby Phase: Lose 300 LP.
local s,id=GetID()
s.listed_names={CARD_EEVEE,CARD_FIRE_STONE}
function s.initial_effect(c)
	Pokemon.AddEeveelution(c,CARD_FIRE_STONE)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(function(e)
		return 300*Duel.GetMatchingGroupCount(function(x) return x:IsFaceup() and x:IsAttribute(ATTRIBUTE_FIRE) end,0,LOCATION_MZONE,LOCATION_MZONE,e:GetHandler())
	end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_PIERCE)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e3:SetOperation(function(e,tp) Duel.SetLP(tp,math.max(0,Duel.GetLP(tp)-300)) end)
	c:RegisterEffect(e3)
end
