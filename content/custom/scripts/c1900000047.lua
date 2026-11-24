-- Nidoran Male
-- If you control a "Nidoran Female", you can Normal Summon this card in addition to your Normal Summon/Set.
-- If this card attacks a Defense Position monster, inflict piercing battle damage.
-- PATTERN: an extra Normal Summon = EFFECT_EXTRA_SUMMON_COUNT. Here it's on the card while it's in
-- your hand, and only applies to itself.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_EXTRA_SUMMON_COUNT)
	e1:SetRange(LOCATION_HAND)
	e1:SetTargetRange(LOCATION_HAND,0)
	e1:SetTarget(function(e,tc) return tc==e:GetHandler() end)   -- only this card
	e1:SetCondition(function(e)
		return Duel.IsExistingMatchingCard(aux.FaceupFilter(Card.IsCode,1900000043),e:GetHandlerPlayer(),LOCATION_MZONE,0,1,nil)
	end)
	c:RegisterEffect(e1)
	-- Piercing
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_PIERCE)
	c:RegisterEffect(e2)
end
s.listed_names={1900000043}
