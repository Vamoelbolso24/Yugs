-- Gengar
-- Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by Tributing 1 "Haunter" you control.
-- If Summoned this way: You can destroy all Set Spells/Traps your opponent controls.
-- Cannot be destroyed by your opponent's Trap effects.
-- Control of this card cannot change.
-- If this card inflicts battle damage to your opponent: Your opponent discards 1 random card.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddNomiSummon(c,1900000150)       -- Tribute 1 Haunter you control
	Pokemon.AddNoControlChange(c)
	Pokemon.AddRandomDiscardOnDamage(c)        -- no once-per-turn limit
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e) return Pokemon.IsNomiSummoned(e:GetHandler()) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local g=Duel.GetMatchingGroup(s.setfilter,tp,0,LOCATION_ONFIELD,nil)
		if chk==0 then return #g>0 end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
	end)
	e1:SetOperation(function(e,tp) Duel.Destroy(Duel.GetMatchingGroup(s.setfilter,tp,0,LOCATION_ONFIELD,nil),REASON_EFFECT) end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
	e2:SetValue(function(e,re) return re:IsActiveType(TYPE_TRAP) and re:GetOwnerPlayer()~=e:GetHandlerPlayer() end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000150}
-- Set Spells/Traps (face-down cards in the Spell & Trap Zones)
function s.setfilter(c) return c:IsFacedown() and c:IsLocation(LOCATION_SZONE) end
