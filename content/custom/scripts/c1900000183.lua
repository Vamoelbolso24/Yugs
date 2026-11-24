-- Chansey's Lucky Punch (Equip Spell)
-- Equip only to "Chansey". The equipped monster can make a second attack during each Battle Phase.
local s,id=GetID()
local CHANSEY=1900000179
function s.initial_effect(c)
	aux.AddEquipProcedure(c,nil,aux.FilterBoolFunction(Card.IsCode,CHANSEY))
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_EXTRA_ATTACK)
	e1:SetValue(1)
	c:RegisterEffect(e1)
end
s.listed_names={CHANSEY}
