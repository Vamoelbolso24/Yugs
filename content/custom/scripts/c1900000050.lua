-- Clefairy
-- (This card can be targeted by the effects of "Moon Stone".)
-- Once per turn: You can excavate the top card of your Deck, and if it is a Normal Spell, immediately
-- apply its effects and then shuffle it into the Deck. If it's not a Normal Spell, place it on the bottom of your Deck.
-- The excavating is shared with Clefable: see Pokemon.ExcavateAndApply in custom_utility.lua.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>0 end
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		Pokemon.ExcavateAndApply(e,tp,eg,ep,ev,re,r,rp,Card.IsNormalSpell)
	end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000046}   -- Moon Stone
