-- Golem
-- Evolution Summon from "Graveler" (hard once per turn).
-- Cannot be destroyed by battle or targeted by the effects of LIGHT monsters.
-- This card can attack while in face-up Defense Position (using its ATK).
-- You can destroy this card, and if you do, destroy all other monsters on the field.
-- If this card battles a WATER monster, at the start of the Damage Step: Destroy this card.
-- (The shared parts are Pokemon.AddRockBody in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000121)   -- from Graveler
	Pokemon.AddRockBody(c)

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
s.listed_names={1900000121}
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	local g=Duel.GetFieldGroup(tp,LOCATION_MZONE,LOCATION_MZONE)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
end
function s.operation(e,tp)
	local c=e:GetHandler()
	if not (c:IsRelateToEffect(e) and Duel.Destroy(c,REASON_EFFECT)>0) then return end
	Duel.Destroy(Duel.GetFieldGroup(tp,LOCATION_MZONE,LOCATION_MZONE),REASON_EFFECT)
end
