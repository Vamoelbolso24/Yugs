-- Stick (Equip Spell)
-- Equip only to "Farfetch'd". The equipped monster gains 800 ATK, also it can make a second attack during each
-- Battle Phase.
local s,id=GetID()
local FARFETCHD=1900000138
function s.initial_effect(c)
	aux.AddEquipProcedure(c,nil,aux.FilterBoolFunction(Card.IsCode,FARFETCHD))
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(800)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_EQUIP)
	e2:SetCode(EFFECT_EXTRA_ATTACK)
	e2:SetValue(1)
	c:RegisterEffect(e2)
end
s.listed_names={FARFETCHD}
