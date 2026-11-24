-- Thick Club (Equip Spell)
-- Equip only to a "Marowak" monster you control. Double the equipped monster's ATK.
-- PATTERN: like the real "Megamorph": its original ATK becomes double (EFFECT_SET_BASE_ATTACK). Other ATK
-- changes (Rain Dance, counters...) are added on top of that.
local s,id=GetID()
function s.initial_effect(c)
	aux.AddEquipProcedure(c,0,aux.FilterBoolFunction(Card.IsSetCard,SET_MAROWAK))
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_SET_BASE_ATTACK)
	e1:SetValue(function(e,tc) return tc:GetBaseAttack()*2 end)
	c:RegisterEffect(e1)
end
s.listed_series={SET_MAROWAK}
