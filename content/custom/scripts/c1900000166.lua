-- Marowak
-- Evolution Summon from "Cubone" (hard once per turn).
-- (This card is also treated as a Spellcaster monster.)
-- Unaffected by LIGHT monsters' effects, also LIGHT monsters can't target this card for attacks.
-- Cannot be destroyed by battle with a monster whose ATK is lower than this card's DEF.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000165)   -- from Cubone
	Pokemon.AddExtraRace(c,RACE_SPELLCASTER)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_IMMUNE_EFFECT)
	e1:SetValue(function(e,te) return te:IsMonsterEffect() and te:GetHandler():IsAttribute(ATTRIBUTE_LIGHT) end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_CANNOT_BE_BATTLE_TARGET)
	e2:SetValue(function(e,ac) return ac:IsAttribute(ATTRIBUTE_LIGHT) end)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetCode(EFFECT_INDESTRUCTABLE_BATTLE)
	e3:SetValue(function(e,bc) return bc:GetAttack()<e:GetHandler():GetDefense() end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000165}
