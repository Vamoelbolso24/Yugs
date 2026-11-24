-- Graveler
-- Evolution Summon from "Geodude" (hard once per turn).
-- Cannot be destroyed by battle or targeted by the effects of LIGHT monsters.
-- This card can attack while in face-up Defense Position (using its ATK).
-- You can destroy this card, and if you do, destroy 1 monster your opponent controls.
-- If this card battles a WATER monster, at the start of the Damage Step: Destroy this card.
-- (The shared parts are Pokemon.AddRockBody in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000120)   -- from Geodude
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
s.listed_names={1900000120}
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(nil,tp,0,LOCATION_MZONE,1,nil) end
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,e:GetHandler(),1,0,0)
end
function s.operation(e,tp)
	local c=e:GetHandler()
	-- destroy itself first; only if that worked, destroy 1 opponent's monster (chosen now, not targeted)
	if not (c:IsRelateToEffect(e) and Duel.Destroy(c,REASON_EFFECT)>0) then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
	local g=Duel.SelectMatchingCard(tp,nil,tp,0,LOCATION_MZONE,1,1,nil)
	if #g>0 then
		Duel.HintSelection(g)
		Duel.Destroy(g,REASON_EFFECT)
	end
end
