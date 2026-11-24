-- Fossil Pkmn - Kabuto
-- Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by banishing 2 WATER monsters from
-- your GY.
-- If a "Fossil Pkmn" monster you control would be destroyed by battle while "Rain Dance" is on the field, you can
-- banish this card from your GY instead. You can only use this effect of "Fossil Pkmn - Kabuto" once per turn.
local s,id=GetID()
s.listed_names={CARD_RAIN_DANCE}
function s.initial_effect(c)
	Pokemon.AddFossilSummon(c,"banish",function(x) return x:IsMonster() and x:IsAttribute(ATTRIBUTE_WATER) end,2)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EFFECT_DESTROY_REPLACE)
	e1:SetRange(LOCATION_GRAVE)
	e1:SetCountLimit(1,id)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return Pokemon.IsOnField(CARD_RAIN_DANCE) and c:IsAbleToRemove() and eg:IsExists(s.repfilter,1,nil,tp) end
		return Duel.SelectEffectYesNo(tp,c,aux.Stringid(id,0))
	end)
	e1:SetValue(function(e,tc) return s.repfilter(tc,e:GetHandlerPlayer()) end)
	e1:SetOperation(function(e) Duel.Remove(e:GetHandler(),POS_FACEUP,REASON_EFFECT|REASON_REPLACE) end)
	c:RegisterEffect(e1)
end
function s.repfilter(c,tp)
	return c:IsFaceup() and c:IsSetCard(SET_FOSSIL_PKMN) and c:IsLocation(LOCATION_MZONE) and c:IsControler(tp)
		and c:IsReason(REASON_BATTLE) and not c:IsReason(REASON_REPLACE)
end
