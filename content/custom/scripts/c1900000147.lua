-- Shellder
-- The first time this card would be destroyed by battle each turn, you can send the top card of your Deck to the
-- GY instead, and if that card was a WATER Pokemon monster, draw 1 card.
-- PATTERN: "would be destroyed ... instead" = EFFECT_DESTROY_REPLACE; "first time each turn" = a flag that
-- lasts until the End Phase.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_DESTROY_REPLACE)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return c:IsReason(REASON_BATTLE) and not c:IsReason(REASON_REPLACE)
			and c:GetFlagEffect(id)==0 and Duel.IsPlayerCanDiscardDeck(tp,1) end
		if not Duel.SelectEffectYesNo(tp,c,aux.Stringid(id,0)) then return false end
		c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1)
		return true
	end)
	e1:SetOperation(function(e,tp)
		local tc=Pokemon.MillTop(tp)
		if Pokemon.IsWaterPokemon(tc) then Duel.Draw(tp,1,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
end
